defmodule CurlReq do
  @moduledoc """
  `CurlReq` bridges the gap between curl and Req.

  Convert a curl command to a `%Req.Request{}` struct with `~CURL`

  Convert a `%Req.Request{}` struct to a curl command with `to_curl/1`.
  """
  @type inspect_opt :: {:label, String.t()}

  @doc """
  Inspect a Req struct in CURL syntax.

  Returns the unchanged `req`, just like `IO.inspect/2`.

  ## Examples

      iex> Req.new(url: URI.parse("https://www.google.com"))
      ...> |> CurlReq.to_curl()
      :world

  """
  @spec inspect(%Req.Request{}, [inspect_opt()]) :: %Req.Request{}
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

  @spec to_curl(%Req.Request{}) :: String.t()
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
  Transforms a CURL command to a %Req.Request{} struct.

  ## Examples

      iex> import CurlReq
      iex> ~CURL"curl https://www.google.com"
      %Req.Request{method: :get, url: %URI{scheme: "https", host: "www.google.com"}}
  """
  defmacro sigil_CURL({:<<>>, _line_info, [command]}, _extra) do
    CurlReq.Macro.parse(command)
    |> to_req()
    |> Macro.escape()
  end

  def to_req(["curl" | rest]) do
    to_req(rest, %Req.Request{})
  end

  def to_req(["-H", header | rest], req) do
    [key, value] = String.split(header, ":", parts: 2)
    new_req = Req.Request.put_header(req, String.trim(key), String.trim(value))
    to_req(rest, new_req)
  end

  def to_req(["-X", method | rest], req) do
    new_req = Req.merge(req, method: method)
    to_req(rest, new_req)
  end

  def to_req(["-d", body | rest], req) do
    new_req = Req.merge(req, body: body)
    to_req(rest, new_req)
  end

  def to_req([url | rest], req) do
    new_req = Req.merge(req, url: url)
    to_req(rest, new_req)
  end

  def to_req([], req), do: req
end
