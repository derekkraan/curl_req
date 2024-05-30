defmodule CurlReq do
  @external_resource "README.md"
  @moduledoc @external_resource
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  @type inspect_opt :: {:label, String.t()}
  @type req_request :: %Req.Request{}

  @doc """
  Inspect a Req struct in curl syntax.

  Returns the unchanged `req`, just like `IO.inspect/2`.

  ## Examples
      iex> Req.new(url: URI.parse("https://www.google.com"))
      ...> |> CurlReq.inspect()
      ...> # |> Req.request!()

  """
  @spec inspect(req_request(), [inspect_opt()]) :: req_request()
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
  @spec to_curl(req_request()) :: String.t()
  def to_curl(req) do
    req = run_steps(req)

    headers =
      Enum.flat_map(req.headers, fn {key, value} ->
        ["-H", "#{key}: #{value}"]
      end)

    body =
      case req.body do
        nil -> []
        body -> ["-d", body]
      end

    method =
      case req.method do
        nil -> ["-X", "GET"]
        m -> ["-X", String.upcase(to_string(m))]
      end

    url = [to_string(req.url)]

    CurlReq.Shell.cmd_to_string("curl", headers ++ body ++ method ++ url)
  end

  @doc """
  Transforms a curl command into a Req request.

  ## Examples

      iex> import CurlReq
      ...> ~CURL(curl "https://www.google.com")
      %Req.Request{method: :get, url: URI.parse("https://www.google.com")}
  """
  defmacro sigil_CURL({:<<>>, _line_info, [command]}, _extra) do
    command
    |> CurlReq.Macro.parse()
    |> CurlReq.Macro.to_req()
    |> Macro.escape()
  end
end
