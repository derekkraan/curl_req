defmodule CurlReq.PlugTest do
  use ExUnit.Case, async: true
  doctest CurlReq.Plug

  alias CurlReq.Request

  describe "decode/1" do
    test "url" do
      assert %Request{
               method: :get,
               url: %URI{scheme: "https", host: "example.com", query: "foo=bar"}
             } =
               %Plug.Conn{
                 scheme: :https,
                 host: "example.com",
                 request_path: "",
                 query_string: "foo=bar"
               }
               |> CurlReq.Plug.decode()
    end

    test "headers" do
      request =
        %Plug.Conn{req_headers: [{"foo", "bar"}]}
        |> CurlReq.Plug.decode()

      assert request.headers == %{"foo" => ["bar"]}
    end

    test "method" do
      request =
        %Plug.Conn{method: "POST"}
        |> CurlReq.Plug.decode()

      assert request.method == :post
    end

    test "" do
      request =
        %Plug.Conn{method: "POST"}
        |> CurlReq.Plug.decode()

      assert request.method == :post
    end
  end

  describe "encode/1" do
    test "all fields" do
      assert %Plug.Conn{
               scheme: :https,
               host: "example.com",
               request_path: "/baz",
               query_string: "foo=bar",
               req_headers: [{"qux", "qaz"}],
               port: 443
             } =
               %Request{
                 url: URI.parse("https://example.com/baz?foo=bar"),
                 headers: %{"qux" => ["qaz"]}
               }
               |> CurlReq.Plug.encode()
    end
  end
end
