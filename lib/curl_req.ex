defmodule CurlReq do
  @req_version :application.get_key(:req, :vsn) |> elem(1)

  @flag_docs CurlReq.Curl.flags()
             |> Enum.map(fn
               {long, nil} -> "* `--#{long}`"
               {long, short} -> "* `--#{long}`/`-#{short}`"
             end)
             |> Enum.join("\n")

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

  The following flags are supported:

  #{@flag_docs}

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
      ~S(curl --header "accept-encoding: gzip" --user-agent "req/#{@req_version}" --request GET https://www.example.com)

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
    options =
      Keyword.validate!(options, flags: :short, run_steps: true, flavor: nil, flavour: :curl)

    flavor = options[:flavor] || options[:flavour]
    flags = options[:flags]
    run_steps = options[:run_steps]

    available_steps = step_names(req, run_steps)
    req = run_steps(req, available_steps)

    curl_options = [flavor: flavor, flags: flags]

    CurlReq.Req.decode(req)
    |> CurlReq.Curl.encode(curl_options)
  end

  @doc """
  Transforms a curl command into a Req request.

  The following flags are supported:

  #{@flag_docs}

  The `curl` command prefix is optional

  > #### Info {: .info}
  >
  > Only string inputs are supported. That means for example `-d @data.txt` will not load the file or `-d @-` will not read from stdin

  ## Examples

      iex> CurlReq.from_curl("curl https://www.example.com")
      %Req.Request{method: :get, url: URI.parse("https://www.example.com")}

      iex> CurlReq.from_curl(~s|curl -d "some data" https://example.com|)
      %Req.Request{method: :get, body: "some data", url: URI.parse("https://example.com")}

      iex> CurlReq.from_curl("curl -I https://example.com")
      %Req.Request{method: :head, url: URI.parse("https://example.com")}

      iex> CurlReq.from_curl("curl -b cookie_key=cookie_val https://example.com")
      %Req.Request{method: :get, headers: %{"cookie" => ["cookie_key=cookie_val"]}, url: URI.parse("https://example.com")}
  """
  @doc since: "0.98.4"

  @spec from_curl(String.t()) :: Req.Request.t()
  def from_curl(curl_command) do
    curl_command
    |> CurlReq.Curl.decode()
    |> CurlReq.Req.encode()
  end

  @doc """
  Same as `from_curl/1` but as a sigil. The benefit here is, that the `Req.Request` struct will be created at compile time and you don't need to escape the string.
  Remember to

  ```elixir
  import CurlReq
  ```

  to use the custom sigil.

  ## Examples

      iex> ~CURL(curl "https://www.example.com")
      %Req.Request{method: :get, url: URI.parse("https://www.example.com")}

      iex> ~CURL(curl -d "some data" "https://example.com")
      %Req.Request{method: :get, body: "some data", url: URI.parse("https://example.com")}

      iex> ~CURL(curl -I "https://example.com")
      %Req.Request{method: :head, url: URI.parse("https://example.com")}

      iex> ~CURL(curl -b "cookie_key=cookie_val" "https://example.com")
      %Req.Request{method: :get, headers: %{"cookie" => ["cookie_key=cookie_val"]}, url: URI.parse("https://example.com")}
  """
  defmacro sigil_CURL(curl_command, modifiers)

  defmacro sigil_CURL({:<<>>, _line_info, [command]}, _extra) do
    command
    |> from_curl()
    |> Macro.escape()
  end
end
