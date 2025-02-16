defmodule CurlReq.Plug do
  alias Plug.Conn
  alias CurlReq.Request

  @moduledoc since: "0.101.0"

  @behaviour CurlReq.Request

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
        %Request{url: uri, body: body, headers: headers, method: method} = _request,
        _opts \\ []
      ) do
    %Conn{
      host: uri.host,
      query_string: uri.query,
      port: uri.port,
      request_path: uri.path,
      method: method |> Atom.to_string() |> String.upcase(),
      req_headers:
        for {key, list} <- headers do
          {key, Enum.join(list, ",")}
        end,
      body_params: body
    }
  end
end
