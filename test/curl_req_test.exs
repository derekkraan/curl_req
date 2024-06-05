defmodule CurlReqTest do
  use ExUnit.Case, async: true
  doctest CurlReq
  import CurlReq

  @req_version :application.get_key(:req, :vsn) |> elem(1)

  defp default_header(), do: "-H \"accept-encoding: gzip\" -H \"user-agent: req/#{@req_version}\""

  describe "to_curl" do
    test "works with base URL" do
      assert "curl #{default_header()} -X GET https://catfact.ninja/fact" ==
               Req.new(url: "/fact", base_url: "https://catfact.ninja/")
               |> CurlReq.to_curl()
    end

    test "cookies get extracted from header" do
      assert Req.new(url: "http://example.com", headers: %{"cookie" => ["name1=value1"]})
             |> CurlReq.to_curl() ==
               "curl #{default_header()} -b \"name1=value1\" -X GET http://example.com"
    end

    test "works when body is iodata" do
      assert "curl #{default_header()} -d hello -X POST https://catfact.ninja/fact" ==
               Req.new(
                 method: :post,
                 url: "/fact",
                 base_url: "https://catfact.ninja",
                 body: ["h" | ["e" | ["llo"]]]
               )
               |> CurlReq.to_curl()
    end
  end
end
