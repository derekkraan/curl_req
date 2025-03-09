defmodule CurlReq.Plug do
  alias Plug.Conn
  alias CurlReq.Request

  require Logger

  @moduledoc since: "0.101.0"

  @behaviour CurlReq.Request

  def init(opts), do: opts

  @doc """

  Logs the request as a cURL command

  ```elixir
  plug CurlReq.Plug
  ```


  You can specify a filter function to only log certain requests. 

  For example don't log routes which start with `/admin`

  ```elixir
  def reject_admin_routes(conn) do
    case conn do
      %{path_info: ["admin" | _]} -> false
      _ -> true
    end
  end

  pipeline :browser do
    ...
    plug CurlReq.Plug, log_level: :error, filter: &__MODULE__.reject_admin_routes/1
  end
  ```
  """

  def call(%Plug.Conn{} = conn, opts) do
    log_level = opts[:log_level] || :debug
    metadata = opts[:log_metadata] || []
    filter = opts[:filter] || fn _conn -> true end

    if not is_function(filter, 1) do
      raise ArgumentError,
            "Filter has to be a 1-arity function which accepts a Plug.Conn struct and returns a boolean"
    end

    if filter.(conn) do
      Logger.log(
        log_level,
        fn ->
          conn
          |> CurlReq.Plug.decode()
          |> CurlReq.Curl.encode()
        end,
        metadata
      )
    end

    conn
  end

  @impl CurlReq.Request
  def decode(%Conn{} = conn, _opts \\ []) do
    %Request{}
    |> put_uri(conn)
    |> put_method(conn.method)
    |> put_headers(conn.req_headers)
    |> put_body(conn)
  end

  defp put_uri(%Request{} = request, %Conn{} = conn) do
    uri = %URI{
      scheme: Atom.to_string(conn.scheme),
      host: conn.host,
      port: conn.port,
      path: conn.request_path,
      query: conn.query_string
    }

    Request.put_url(request, uri)
  end

  defp put_method(%Request{} = request, method) do
    method =
      method
      |> String.downcase()
      |> String.to_existing_atom()

    Request.put_method(request, method)
  end

  defp put_headers(%Request{} = request, headers) do
    for {key, val} <- headers, reduce: request do
      request -> Request.put_header(request, key, val)
    end
  end

  defp put_body(%Request{method: method} = request, %Conn{body_params: body})
       when not is_struct(body)
       when method in [:post, :put, :patch, :delete] do
    Request.put_body(request, body)
  end

  defp put_body(request, _conn), do: request

  @impl CurlReq.Request
  def encode(
        %Request{url: uri, headers: headers, method: method} = request,
        _opts \\ []
      ) do
    %Conn{
      scheme: uri.scheme |> String.to_existing_atom(),
      host: uri.host,
      query_string: uri.query,
      port: uri.port,
      request_path: uri.path,
      method: method |> Atom.to_string() |> String.upcase(),
      req_headers:
        for {key, list} <- headers do
          {key, Enum.join(list, ",")}
        end,
      body_params: get_body(request)
    }
  end

  defp get_body(%Request{method: method, body: body})
       when method in [:post, :put, :patch, :delete] do
    body
  end

  defp get_body(%Request{method: _method, body: _body}) do
    %Plug.Conn.Unfetched{aspect: :body_params}
  end
end
