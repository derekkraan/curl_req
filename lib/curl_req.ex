defmodule CurlReq do
  @external_resource "README.md"
  @moduledoc @external_resource
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  @req_version :application.get_key(:req, :vsn) |> elem(1)

  @doc false
  def req_version(), do: @req_version

  @type inspect_opt :: {:label, String.t()}

  @doc """
  Inspect a Req struct in curl syntax.

  Returns the unchanged `req`, just like `IO.inspect/2`.

  ## Examples
      Req.new(url: "https://example.com")
      |> CurlReq.inspect()
      |> Req.request!()
      #=> curl --compressed -X GET https://example.com

  """
  @spec inspect(Req.Request.t(), [inspect_opt()]) :: Req.Request.t()
  def inspect(req, opts \\ []) do
    case Keyword.get(opts, :label) do
      nil -> IO.puts(to_curl(req))
      label -> IO.puts([label, ": ", to_curl(req)])
    end

    req
  end

  @spec step_names(Req.Request.t(), boolean()) :: [atom()]
  defp step_names(%Req.Request{} = _req, false), do: []
  defp step_names(%Req.Request{} = req, true), do: req.request_steps |> Keyword.keys()

  @spec step_names(Req.Request.t(), [atom()]) :: [atom()]
  defp step_names(%Req.Request{} = req, except: excludes) do
    for {name, _} <- req.request_steps, name not in excludes do
      name
    end
  end

  defp step_names(%Req.Request{} = req, only: includes) do
    for {name, _} <- req.request_steps, name in includes do
      name
    end
  end

  @spec run_steps(Req.Request.t(), [atom()]) :: Req.Request.t()
  defp run_steps(req, steps) do
    req.request_steps
    |> Enum.filter(fn {step, _} ->
      step in steps
    end)
    |> Enum.reduce(req, fn {step_name, step}, req ->
      case step.(req) do
        {_req, _response_or_error} ->
          raise "The request was stopped by #{step_name} request_step."

        next_req ->
          next_req
      end
    end)
  end

  @doc """
  Transforms a Req request into a curl command.

  Supported curl flags are:

  * `-b`/`--cookie`
  * `-H`/`--header`
  * `-X`/`--request`
  * `-L`/`--location`
  * `-I`/`--head`
  * `-d`/`--data`/`--data-ascii`
  * `--data-raw`
  * `-x`/`--proxy`
  * `-U`/`--proxy-user`
  * `-u`/`--user`
  * `-n`/`--netrc`
  * `--netrc-file`

  Options:

  - `run_steps`: Run the Req.Steps before generating the curl command to have fine-tuned control over the Req.Request. Default: `true`. 
    * `true`: Run all steps
    * `false`: Run no steps
    * `only: [atom()]`: A list of step names as atoms and only they will be executed
    * `except: [atom()]`: A list of step names as atoms and these steps will be excluded from the executed steps
  - `flags`: Specify the style the argument flags are constructed. Can either be `:short` or `:long`, Default: `:short`
  - `flavor` or `flavour`: With the `:curl` flavor (the default) it will try to use native curl representations for compression, auth and will use the native user agent. 
  If flavor is set to `:req` the headers will not be modified and the curl command is constructed to stay as true as possible to the original `Req.Request`

  ## Examples

      iex> Req.new(url: URI.parse("https://www.example.com"))
      ...> |> CurlReq.to_curl()
      ~S(curl --compressed -X GET https://www.example.com)

      iex> Req.new(url: URI.parse("https://www.example.com"))
      ...> |> CurlReq.to_curl(flags: :long, flavor: :req)
      ~S(curl --header "accept-encoding: gzip" --header "user-agent: req/#{@req_version}" --request GET https://www.example.com)

      iex> Req.new(url: "https://www.example.com")
      ...> |> CurlReq.to_curl(run_steps: [except: [:compressed]])
      ~S(curl -X GET https://www.example.com)
  """
  @type flags :: :short | :long
  @type flavor :: :curl | :req
  @type to_curl_opts :: [
          flags: flags(),
          flavor: flavor(),
          flavour: flavor(),
          run_steps: boolean() | [only: [atom()]] | [except: [atom()]]
        ]
  @spec to_curl(Req.Request.t(), to_curl_opts()) :: String.t()
  def to_curl(req, options \\ []) do
    opts = Keyword.validate!(options, flags: :short, run_steps: true, flavor: nil, flavour: :curl)
    flavor = opts[:flavor] || opts[:flavour]
    flag_style = opts[:flags]
    run_steps = opts[:run_steps]

    available_steps = step_names(req, run_steps)
    req = run_steps(req, available_steps)

    cookies =
      case Map.get(req.headers, "cookie") do
        nil -> []
        [cookies] -> [cookie_flag(flag_style), cookies]
      end

    headers =
      req.headers
      |> Enum.reject(fn {key, _val} -> key == "cookie" end)
      |> Enum.flat_map(&map_header(&1, flag_style, flavor))

    body =
      case req.body do
        nil -> []
        body -> [data_flag(flag_style), body]
      end

    options =
      case req.options do
        %{redirect: true} ->
          [location_flag(flag_style)]

        # avoids duplicate compression argument
        %{compressed: true} ->
          if :compressed in available_steps, do: [], else: [compressed_flag()]

        %{connect_options: connect_options} ->
          proxy =
            case Keyword.get(connect_options, :proxy) do
              nil ->
                []

              {scheme, host, port, _} ->
                [proxy_flag(flag_style), "#{scheme}://#{host}:#{port}"]
            end

          case Keyword.get(connect_options, :proxy_headers) do
            [{"proxy-authorization", "Basic " <> encoded_creds}] ->
              proxy ++ [proxy_user_flag(flag_style), Base.decode64!(encoded_creds)]

            _ ->
              proxy
          end

        _ ->
          []
      end

    auth =
      with %{auth: scheme} <- req.options do
        case scheme do
          {:bearer, token} ->
            [header_flag(flag_style), "authorization: Bearer #{token}"]

          {:basic, userinfo} ->
            [user_flag(flag_style), userinfo] ++ [basic_auth_flag()]

          :netrc ->
            [netrc_flag(flag_style)]

          {:netrc, filepath} ->
            [netrc_file_flag(flag_style), filepath]

          _ ->
            []
        end
      else
        _ ->
          []
      end

    method =
      case req.method do
        nil -> [request_flag(flag_style), "GET"]
        :head -> [head_flag(flag_style)]
        m -> [request_flag(flag_style), String.upcase(to_string(m))]
      end

    url = [to_string(req.url)]

    CurlReq.Shell.cmd_to_string(
      "curl",
      auth ++ headers ++ cookies ++ body ++ options ++ method ++ url
    )
  end

  @typep header :: {String.t(), list(String.t())}
  @spec map_header(header(), flags(), flavor()) :: list()
  defp map_header({"accept-encoding", [compression]}, _flag_style, :curl)
       when compression in ["gzip", "br", "zstd"] do
    [compressed_flag()]
  end

  # filter out auth header because we expect it to be set as an auth step option
  defp map_header({"authorization", _}, _flag_style, :curl),
    do: []

  # filter out user agent when mode is :curl
  defp map_header({"user-agent", ["req/" <> _]}, _, :curl), do: []

  defp map_header({key, value}, flag_style, _),
    do: [header_flag(flag_style), "#{key}: #{value}"]

  defp cookie_flag(:short), do: "-b"
  defp cookie_flag(:long), do: "--cookie"

  defp header_flag(:short), do: "-H"
  defp header_flag(:long), do: "--header"

  defp data_flag(:short), do: "-d"
  defp data_flag(:long), do: "--data"

  defp head_flag(:short), do: "-I"
  defp head_flag(:long), do: "--head"

  defp request_flag(:short), do: "-X"
  defp request_flag(:long), do: "--request"

  defp location_flag(:short), do: "-L"
  defp location_flag(:long), do: "--location"

  defp user_flag(:short), do: "-u"
  defp user_flag(:long), do: "--user"

  defp basic_auth_flag(), do: "--basic"

  defp compressed_flag(), do: "--compressed"

  defp proxy_flag(:short), do: "-x"
  defp proxy_flag(:long), do: "--proxy"

  defp proxy_user_flag(:short), do: "-U"
  defp proxy_user_flag(:long), do: "--proxy-user"

  defp netrc_flag(:short), do: "-n"
  defp netrc_flag(:long), do: "--netrc"

  defp netrc_file_flag(_), do: "--netrc-file"

  @doc """
  Transforms a curl command into a Req request.

  Supported curl command line flags are supported:

  * `-H`/`--header`
  * `-X`/`--request`
  * `-d`/`--data`
  * `-b`/`--cookie`
  * `-I`/`--head`
  * `-F`/`--form`
  * `-L`/`--location`
  * `-u`/`--user`
  * `-x`/`--proxy`
  * `-U`/`--proxy-user`
  * `--compressed`

  The `curl` command prefix is optional

  > #### Info {: .info}
  >
  > Only string inputs are supported. That means for example `-d @data.txt` will not load the file or `-d @-` will not read from stdin

  ## Examples

      iex> CurlReq.from_curl("curl https://www.example.com")
      %Req.Request{method: :get, url: URI.parse("https://www.example.com")}

      iex> ~S(curl -d "some data" https://example.com) |> CurlReq.from_curl()
      %Req.Request{method: :get, body: "some data", url: URI.parse("https://example.com")}

      iex> CurlReq.from_curl("curl -I https://example.com")
      %Req.Request{method: :head, url: URI.parse("https://example.com")}

      iex> CurlReq.from_curl("curl -b cookie_key=cookie_val https://example.com")
      %Req.Request{method: :get, headers: %{"cookie" => ["cookie_key=cookie_val"]}, url: URI.parse("https://example.com")}
  """
  @doc since: "0.98.4"

  @spec from_curl(String.t()) :: Req.Request.t()
  def from_curl(curl_command), do: CurlReq.Macro.parse(curl_command)

  @doc """
  Same as `from_curl/1` but as a sigil. The benefit here is, that the Req.Request struct will be created at compile time and you don't need to escape the string

  ## Examples

      iex> import CurlReq
      ...> ~CURL(curl "https://www.example.com")
      %Req.Request{method: :get, url: URI.parse("https://www.example.com")}

      iex> import CurlReq
      ...> ~CURL(curl -d "some data" "https://example.com")
      %Req.Request{method: :get, body: "some data", url: URI.parse("https://example.com")}

      iex> import CurlReq
      ...> ~CURL(curl -I "https://example.com")
      %Req.Request{method: :head, url: URI.parse("https://example.com")}

      iex> import CurlReq
      ...> ~CURL(curl -b "cookie_key=cookie_val" "https://example.com")
      %Req.Request{method: :get, headers: %{"cookie" => ["cookie_key=cookie_val"]}, url: URI.parse("https://example.com")}
  """
  defmacro sigil_CURL(curl_command, modifiers)

  defmacro sigil_CURL({:<<>>, _line_info, [command]}, _extra) do
    command
    |> CurlReq.Macro.parse()
    |> Macro.escape()
  end
end
