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

  ## Examples

      iex> Req.new(url: URI.parse("https://www.google.com"))
      ...> |> CurlReq.to_curl()
      ~S(curl -H "accept-encoding: gzip" -H "user-agent: req/0.4.14" -X GET https://www.google.com)

  """
  @spec to_curl(Req.Request.t(), Keyword.t()) :: String.t()
  def to_curl(req, options \\ []) do
    req =
      if Keyword.get(options, :run_steps, true) do
        run_steps(req)
      else
        req
      end

    auth =
      case req.options do
        %{auth: {:basic, credentials}} -> ["-u", credentials]
        _ -> []
      end

    cookies =
      case Map.get(req.headers, "cookie") do
        nil -> []
        [cookies] -> ["-b", cookies]
      end

    headers =
      req.headers
      |> maybe_remove_auth_header(auth)
      |> Enum.reject(fn {key, _val} -> key == "cookie" end)
      |> Enum.flat_map(fn {key, value} ->
        ["-H", "#{key}: #{value}"]
      end)

    body =
      case req.body do
        nil -> []
        body -> ["-d", body]
      end

    redirect =
      case req.options do
        %{redirect: true} -> ["-L"]
        _ -> []
      end

    method =
      case req.method do
        nil -> ["-X", "GET"]
        :head -> ["-I"]
        m -> ["-X", String.upcase(to_string(m))]
      end

    url = [to_string(req.url)]

    CurlReq.Shell.cmd_to_string(
      "curl",
      headers ++ cookies ++ body ++ method ++ redirect ++ auth ++ url
    )
  end

  defp maybe_remove_auth_header(headers, []), do: headers

  defp maybe_remove_auth_header(headers, _),
    do: Enum.reject(headers, fn {key, _val} -> key == "authorization" end)

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

  @spec from_curl(String.t()) :: Req.Request.t()
  def from_curl(curl_command), do: CurlReq.Macro.parse(curl_command)

  @doc """
  Same as `from_curl/1` but as a sigil. The benefit here is, that you don't need to escape the string

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
