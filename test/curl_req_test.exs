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

    test "redirect flag gets set" do
      assert Req.new(url: "http://example.com", redirect: true)
             |> CurlReq.to_curl() ==
               "curl #{default_header()} -X GET -L http://example.com"
    end

    test "head method flag gets set" do
      assert Req.new(url: "http://example.com", method: :head)
             |> CurlReq.to_curl() ==
               "curl #{default_header()} -I http://example.com"
    end

    test "long flags" do
      assert Req.new(
               url: "http://example.com",
               method: :head,
               redirect: true,
               headers: %{"cookie" => ["name1=value1"], "content-type" => ["application/json"]}
             )
             |> CurlReq.to_curl(flags: :long) ==
               "curl --header \"accept-encoding: gzip\" --header \"content-type: application/json\" --header \"user-agent: req/#{@req_version}\" --cookie \"name1=value1\" --head --location http://example.com"
    end

    test "formdata flags get set with correct headers and body" do
      assert Req.new(url: "http://example.com", form: [key1: "value1", key2: "value2"])
             |> CurlReq.to_curl() ==
               "curl -H \"accept-encoding: gzip\" -H \"content-type: application/x-www-form-urlencoded\" -H \"user-agent: req/#{@req_version}\" -d \"key1=value1&key2=value2\" -X GET http://example.com"
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
