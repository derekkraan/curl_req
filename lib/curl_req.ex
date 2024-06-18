defmodule CurlReq do
  @external_resource "README.md"
  @moduledoc @external_resource
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  @type inspect_opt :: {:label, String.t()}

  @doc """
  Inspect a Req struct in curl syntax.

  Returns the unchanged `req`, just like `IO.inspect/2`.

  ## Examples
      iex> Req.new(url: URI.parse("https://www.google.com"))
      ...> |> CurlReq.inspect()
      ...> # |> Req.request!()

  """
  @spec inspect(Req.Request.t(), [inspect_opt()]) :: Req.Request.t()
  def inspect(req, opts \\ []) do
    case Keyword.get(opts, :label) do
      nil -> IO.puts(to_curl(req))
      label -> IO.puts([label, ": ", to_curl(req)])
    end

    req
  end

  defp run_steps(req) do
    Enum.reduce(req.request_steps, req, fn {step_name, step}, req ->
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
  * `-d`/`--data`

  Options:

  - `run_steps`: Run the Req.Steps before generation the arguments. Default: `true`
  - `flags`: Specify the style the argument flags are constructed. Can either be `:short` or `:long`, Default: `:short`

  ## Examples

      iex> Req.new(url: URI.parse("https://www.google.com"))
      ...> |> CurlReq.to_curl()
      ~S(curl -H "accept-encoding: gzip" -H "user-agent: req/0.4.14" -X GET https://www.google.com)

      iex> Req.new(url: URI.parse("https://www.google.com"))
      ...> |> CurlReq.to_curl(flags: :long)
      ~S(curl --header "accept-encoding: gzip" --header "user-agent: req/0.4.14" --request GET https://www.google.com)

  """
  @spec to_curl(Req.Request.t(), Keyword.t()) :: String.t()
  def to_curl(req, options \\ []) do
    flag_style = Keyword.get(options, :flags, :short)

    req =
      if Keyword.get(options, :run_steps, true) do
        run_steps(req)
      else
        req
      end

    cookies =
      case Map.get(req.headers, "cookie") do
        nil -> []
        [cookies] -> [cookie_flag(flag_style), cookies]
      end

    headers =
      req.headers
      |> Enum.reject(fn {key, _val} -> key == "cookie" end)
      |> Enum.flat_map(fn {key, value} ->
        [header_flag(flag_style), "#{key}: #{value}"]
      end)

    body =
      case req.body do
        nil -> []
        body -> [data_flag(flag_style), body]
      end

    redirect =
      case req.options do
        %{redirect: true} -> [location_flag(flag_style)]
        _ -> []
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
      headers ++ cookies ++ body ++ method ++ redirect ++ url
    )
  end

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

  The `curl` command prefix is optional

  > #### Info {: .info}
  >
  > Only string inputs are supported. That means for example `-d @data.txt` will not load the file or `-d @-` will not read from stdin

  ## Examples

      iex> CurlReq.from_curl("curl https://www.google.com")
      %Req.Request{method: :get, url: URI.parse("https://www.google.com")}

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
      ...> ~CURL(curl "https://www.google.com")
      %Req.Request{method: :get, url: URI.parse("https://www.google.com")}

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
