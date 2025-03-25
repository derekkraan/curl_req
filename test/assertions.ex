defmodule CurlReq.Assertions do
  import ExUnit.Assertions

  def assert_url(%Req.Request{} = req, uri) when is_binary(uri) do
    assert_url(req, URI.parse(uri))
  end

  def assert_url(%Req.Request{} = req, %URI{} = uri) do
    assert req.url == uri, "Expected request URI #{inspect(req.url)} to equal #{inspect(uri)}"
    req
  end

  def assert_option(%Req.Request{} = req, option, value) do
    assert Req.Request.fetch_option!(req, option) == value
    req
  end

  def assert_redirect(%Req.Request{} = req) do
    assert_option(req, :redirect, true)
  end

  def assert_compressed(%Req.Request{} = req) do
    assert_option(req, :compressed, true)
  end

  def assert_form(%Req.Request{} = req, form) do
    assert_option(req, :form, form)
  end

  def assert_json(%Req.Request{} = req, json) do
    assert_option(req, :json, json)
  end

  def assert_auth(%Req.Request{} = req, :bearer, token) do
    assert_option(req, :auth, {:bearer, token})
  end

  def assert_auth(%Req.Request{} = req, :basic, userinfo) do
    assert_option(req, :auth, {:basic, userinfo})
  end

  def assert_auth(%Req.Request{} = req, :proxy, userinfo) do
    connect_options = Req.Request.fetch_option!(req, :connect_options)
    userinfo = Base.encode64(userinfo)

    assert [{"proxy-authorization", "Basic " <> ^userinfo}] =
             Keyword.fetch!(connect_options, :proxy_headers)
  end

  def assert_proxy(%Req.Request{} = req, scheme, host, port) when scheme in [:http, :https] do
    connect_options = Req.Request.fetch_option!(req, :connect_options)
    assert {^scheme, ^host, ^port, _} = Keyword.fetch!(connect_options, :proxy)
    req
  end

  def assert_insecure(%Req.Request{} = req) do
    connect_options = Req.Request.fetch_option!(req, :connect_options)
    transport_opts = Keyword.fetch!(connect_options, :transport_opts)
    assert :verify_none == Keyword.fetch!(transport_opts, :verify)
    req
  end

  def assert_protocol(%Req.Request{} = req, protocol) when protocol in [:http1, :http2] do
    connect_options = Req.Request.get_option(req, :connect_options, [])
    protocols = Keyword.get(connect_options, :protocols, [:http1])
    assert protocol in protocols
    req
  end

  def assert_cookie(%Req.Request{} = req, cookie) when is_binary(cookie) do
    case req.headers["cookie"] do
      [cookies] ->
        assert String.contains?(cookies, cookie)
        req

      other ->
        flunk("Expected cookie header to contain #{cookie}, got: #{other}")
    end
  end

  def assert_header(%Req.Request{} = req, name, value)
      when is_binary(name) and is_list(value) do
    assert Req.Request.get_header(req, name) == value
    req
  end

  def assert_method(%Req.Request{} = req, method)
      when method in [:get, :post, :put, :patch, :head] do
    assert req.method == method
    req
  end
end
