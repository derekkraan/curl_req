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
          compressed: :boolean
        ],
        aliases: [
          H: :header,
          X: :request,
          d: :data,
          b: :cookie,
          I: :head,
          F: :form,
          L: :location,
          u: :user
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
    # Can be removed the Req uses URI.new/1
    |> Req.merge(url: URI.to_string(url))
    |> add_header(options)
    |> add_method(options)
    |> add_body(options)
    |> add_cookie(options)
    |> add_form(options)
    |> add_auth(options)
    |> add_compression(options)
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
