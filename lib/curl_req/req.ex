defmodule CurlReq.Req do
  # TODO: docs
  @behaviour CurlReq.Request

  @impl CurlReq.Request
  @spec decode(Req.Request.t()) :: CurlReq.Request.t()
  def decode(%Req.Request{} = req, _opts \\ []) do
    request =
      %CurlReq.Request{}
      |> put_header(req)
      |> CurlReq.Request.put_auth(req.options[:auth])
      |> CurlReq.Request.put_redirect(req.options[:redirect])
      |> CurlReq.Request.put_compression(req.options[:compressed])
      |> CurlReq.Request.put_user_agent(:req)
      |> CurlReq.Request.put_body(req.body)
      |> CurlReq.Request.put_url(req.url)
      |> CurlReq.Request.put_method(req.method)

    request =
      case req.options[:connect_options] do
        nil ->
          request

        connect_options ->
          userinfo =
            case Keyword.get(connect_options, :proxy_headers) do
              [{"proxy-authorization", "Basic " <> encoded_userinfo}] ->
                case Base.decode64(encoded_userinfo) do
                  {:ok, userinfo} -> userinfo
                  _ -> encoded_userinfo
                end

              _ ->
                nil
            end

          case Keyword.get(connect_options, :proxy) do
            {scheme, host, port, _} ->
              CurlReq.Request.put_proxy(request, %URI{
                scheme: Atom.to_string(scheme),
                host: host,
                port: port,
                userinfo: userinfo
              })

            _ ->
              request
          end
      end

    request
  end

  defp put_header(%CurlReq.Request{} = request, %Req.Request{} = req) do
    for {key, val} <- req.headers, reduce: request do
      request -> CurlReq.Request.put_header(request, key, val)
    end
  end

  @impl CurlReq.Request
  @spec encode(CurlReq.Request.t()) :: Req.Request.t()
  def encode(%CurlReq.Request{} = request, _opts \\ []) do
    req =
      %Req.Request{}
      |> Req.merge(url: request.url)
      |> Req.merge(method: request.method)

    cookies =
      request.cookies
      |> Enum.map(fn {key, val} -> "#{key}=#{val}" end)
      |> Enum.join(";")

    req =
      case request.user_agent do
        :req -> req
        :curl -> req
        other -> Req.Request.put_header(req, "user-agent", other)
      end

    req =
      case request.encoding do
        :raw ->
          Req.merge(req, body: request.body)

        :form ->
          req
          |> Req.Request.register_options([:form])
          |> Req.Request.prepend_request_steps(encode_body: &Req.Steps.encode_body/1)
          |> Req.merge(form: request.body)

        :json ->
          req
          |> Req.Request.register_options([:json])
          |> Req.Request.prepend_request_steps(encode_body: &Req.Steps.encode_body/1)
          |> Req.merge(json: request.body)
      end

    req =
      case request.auth do
        :none ->
          req

        auth ->
          req
          |> Req.Request.register_options([:auth])
          |> Req.Request.prepend_request_steps(auth: &Req.Steps.auth/1)
          |> Req.merge(auth: auth)
      end

    req =
      case request.compression do
        :none ->
          req

        _ ->
          req
          |> Req.Request.register_options([:compressed])
          |> Req.Request.prepend_request_steps(compressed: &Req.Steps.compressed/1)
          |> Req.merge(compressed: true)
      end

    req =
      case request.redirect do
        false ->
          req

        _ ->
          req
          |> Req.Request.register_options([:redirect])
          |> Req.Request.prepend_response_steps(redirect: &Req.Steps.redirect/1)
          |> Req.merge(redirect: true)
      end

    req =
      for {key, values} <- request.headers, reduce: req do
        req -> Req.Request.put_header(req, key, values)
      end

    req =
      if cookies != "" do
        Req.Request.put_header(req, "cookie", cookies)
      else
        req
      end

    req =
      if request.proxy do
        %URI{scheme: scheme, host: host, port: port} = request.proxy_url

        connect_options =
          [
            proxy: {String.to_existing_atom(scheme), host, port, []}
          ]

        connect_options =
          case request.proxy_auth do
            :none ->
              connect_options

            {:basic, userinfo} ->
              Keyword.merge(connect_options,
                proxy_headers: [
                  {"proxy-authorization", "Basic " <> Base.encode64(userinfo)}
                ]
              )

            _ ->
              connect_options
          end

        req
        |> Req.Request.register_options([
          :connect_options
        ])
        |> Req.merge(connect_options: connect_options)
      else
        req
      end

    req
  end
end
