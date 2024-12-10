defmodule CurlReq.Macro do
  @moduledoc false

  @spec parse(String.t()) :: Req.Request.t()
  def parse(command) do
    command =
      command
      |> String.trim()
      |> String.trim_leading("curl")
      |> String.replace("\\\n", " ")
      |> String.replace("\n", " ")

    {options, rest, _invalid} =
      command
      |> OptionParser.split()
      |> OptionParser.parse(
        strict: [
          header: :keep,
          request: :string,
          data: :keep,
          data_raw: :keep,
          data_ascii: :keep,
          cookie: :string,
          head: :boolean,
          form: :keep,
          location: :boolean,
          user: :string,
          compressed: :boolean,
          proxy: :string,
          proxy_user: :string
        ],
        aliases: [
          H: :header,
          X: :request,
          d: :data,
          b: :cookie,
          I: :head,
          F: :form,
          L: :location,
          u: :user,
          x: :proxy,
          U: :proxy_user
        ]
      )

    [url] =
      rest
      |> Enum.flat_map(fn part ->
        case URI.new(part) do
          {:ok, uri} -> [uri]
          _ -> []
        end
      end)

    %Req.Request{}
    # Req would accept an URI struct but here we use to_string/1 because Req uses URI.parse/1 which sets the deprecated `authority` field which upsets the test assertions.
    # Can be removed when Req uses URI.new/1
    |> Req.merge(url: URI.to_string(url))
    |> add_header(options)
    |> add_method(options)
    |> add_body(options)
    |> add_cookie(options)
    |> add_form(options)
    |> add_auth(options)
    |> add_compression(options)
    |> add_proxy(options)
    |> configure_redirects(options)
  end

  defp add_header(req, options) do
    headers = Keyword.get_values(options, :header)

    for header <- headers, reduce: req do
      req ->
        [key, value] =
          header
          |> String.split(":", parts: 2)
          |> Enum.map(&String.trim/1)

        case {String.downcase(key), value} do
          {"authorization", "Bearer " <> token} ->
            req
            |> Req.Request.register_options([:auth])
            |> Req.Request.prepend_request_steps(auth: &Req.Steps.auth/1)
            |> Req.merge(auth: {:bearer, token})

          _ ->
            Req.Request.put_header(req, key, value)
        end
    end
  end

  defp add_method(req, options) do
    method =
      if Keyword.get(options, :head, false) do
        :head
      else
        options
        |> Keyword.get(:request, "GET")
        |> String.downcase()
        |> String.to_existing_atom()
      end

    Req.merge(req, method: method)
  end

  defp add_body(req, options) do
    body =
      Enum.flat_map([:data, :data_ascii, :data_raw], fn key ->
        case Keyword.get_values(options, key) do
          [] -> []
          ["$" <> data] -> [data]
          values -> values
        end
      end)
      |> case do
        [] -> nil
        data -> Enum.join(data, "&")
      end

    Req.merge(req, body: body)
  end

  defp add_cookie(req, options) do
    case Keyword.get(options, :cookie) do
      nil -> req
      cookie -> Req.Request.put_header(req, "cookie", cookie)
    end
  end

  defp add_form(req, options) do
    case Keyword.get_values(options, :form) do
      [] ->
        req

      formdata ->
        form =
          for fd <- formdata, reduce: %{} do
            map ->
              [key, value] = String.split(fd, "=", parts: 2)
              Map.put(map, key, value)
          end

        req
        |> Req.Request.register_options([:form])
        |> Req.Request.prepend_request_steps(encode_body: &Req.Steps.encode_body/1)
        |> Req.merge(form: form)
    end
  end

  defp add_auth(req, options) do
    case Keyword.get(options, :user) do
      nil ->
        req

      credentials ->
        req
        |> Req.Request.register_options([:auth])
        |> Req.Request.prepend_request_steps(auth: &Req.Steps.auth/1)
        |> Req.merge(auth: {:basic, credentials})
    end
  end

  defp add_compression(req, options) do
    case Keyword.get(options, :compressed) do
      nil ->
        req

      bool ->
        req
        |> Req.Request.register_options([:compressed])
        |> Req.Request.prepend_request_steps(compressed: &Req.Steps.compressed/1)
        |> Req.merge(compressed: bool)
    end
  end

  defp add_proxy(req, options) do
    with proxy when is_binary(proxy) <- Keyword.get(options, :proxy),
         %URI{scheme: scheme, port: port, host: host} when scheme in ["http", "https"] <-
           validate_proxy_uri(proxy) do
      connect_options =
        [
          proxy: {String.to_existing_atom(scheme), host, port, []}
        ]
        |> maybe_add_proxy_auth(options)

      req
      |> Req.Request.register_options([
        :connect_options
      ])
      |> Req.merge(connect_options: connect_options)
    else
      _ -> req
    end
  end

  defp validate_proxy_uri("http://" <> _rest = uri), do: URI.parse(uri)
  defp validate_proxy_uri("https://" <> _rest = uri), do: URI.parse(uri)

  defp validate_proxy_uri(uri) do
    case String.split(uri, "://") do
      [scheme, _uri] ->
        raise ArgumentError, "Unsupported scheme #{scheme} for proxy in #{uri}"

      [uri] ->
        URI.parse("http://" <> uri)
    end
  end

  defp maybe_add_proxy_auth(connect_options, options) do
    proxy_headers =
      case Keyword.get(options, :proxy_user) do
        nil ->
          []

        credentials ->
          [
            proxy_headers: [
              {"proxy-authorization", "Basic " <> Base.encode64(credentials)}
            ]
          ]
      end

    Keyword.merge(connect_options, proxy_headers)
  end

  defp configure_redirects(req, options) do
    if Keyword.get(options, :location, false) do
      req
      |> Req.Request.register_options([:redirect])
      |> Req.Request.prepend_response_steps(redirect: &Req.Steps.redirect/1)
      |> Req.merge(redirect: true)
    else
      req
    end
  end
end
