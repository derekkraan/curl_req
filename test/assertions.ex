defmodule CurlReq.Assertions do
  import ExUnit.Assertions

  def assert_url(%Req.Request{} = req, uri) do
    expected_uri =
      cond do
        is_binary(uri) ->
          URI.parse(uri)

        is_struct(uri, URI) ->
          uri

        true ->
          flunk("Expected a string or %URI{} for the second argument, got: #{inspect(uri)}")
      end

    assert req.url == expected_uri,
           "Expected request URI #{inspect(req.url)} to equal #{inspect(expected_uri)}"
  end

  def assert_redirect(%Req.Request{} = req) do
    assert req.options[:redirect] == true,
           "Expected redirect to be `true`, got: #{inspect(req.options[:redirect])}"
  end

  def assert_cookie(%Req.Request{} = req, cookie) when is_binary(cookie) do
    case req.headers["cookie"] do
      [cookies] ->
        assert String.contains?(cookies, cookie)

      other ->
        flunk("Expected cookie header to contain #{cookie}, got: #{other}")
    end
  end
end
