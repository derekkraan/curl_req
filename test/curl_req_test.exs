defmodule CurlReqTest do
  use ExUnit.Case, async: true
  doctest CurlReq
  import CurlReq
  import ExUnit.CaptureIO

  describe "inspect" do
    test "without label" do
      assert capture_io(fn ->
               Req.new(url: "/without_label", base_url: "https://example.com/")
               |> CurlReq.inspect()
             end) === "curl --compressed -X GET https://example.com/without_label\n"
    end

    test "with label" do
      assert capture_io(fn ->
               Req.new(url: "/with_label", base_url: "https://example.com/")
               |> CurlReq.inspect(label: "MY REQ")
             end) === "MY REQ: curl --compressed -X GET https://example.com/with_label\n"
    end
  end

  describe "to_curl" do
    test "works with base URL" do
      assert "curl --compressed -X GET https://example.com/fact" ==
               Req.new(url: "/fact", base_url: "https://example.com/")
               |> CurlReq.to_curl()
    end

    test "cookies get extracted from header" do
      assert Req.new(url: "http://example.com", headers: %{"cookie" => ["name1=value1"]})
             |> CurlReq.to_curl() ==
               "curl --compressed -b \"name1=value1\" -X GET http://example.com"
    end

    test "redirect flag gets set" do
      assert Req.new(url: "http://example.com", redirect: true)
             |> CurlReq.to_curl() ==
               "curl --compressed -L -X GET http://example.com"
    end

    test "head method flag gets set" do
      assert Req.new(url: "http://example.com", method: :head)
             |> CurlReq.to_curl() ==
               "curl --compressed -I http://example.com"
    end

    test "long flags" do
      assert Req.new(
               url: "http://example.com",
               method: :head,
               redirect: true,
               headers: %{"cookie" => ["name1=value1"], "content-type" => ["application/json"]}
             )
             |> CurlReq.to_curl(flags: :long) ==
               "curl --compressed --header \"content-type: application/json\" --cookie \"name1=value1\" --location --head http://example.com"
    end

    test "formdata flags get set with correct headers and body" do
      assert Req.new(url: "http://example.com", form: [key1: "value1", key2: "value2"])
             |> CurlReq.to_curl() ==
               "curl --compressed -H \"content-type: application/x-www-form-urlencoded\" -d \"key1=value1&key2=value2\" -X GET http://example.com"
    end

    test "works when body is iodata" do
      assert "curl --compressed -d hello -X POST https://example.com/fact" ==
               Req.new(
                 method: :post,
                 url: "/fact",
                 base_url: "https://example.com",
                 body: ["h" | ["e" | ["llo"]]]
               )
               |> CurlReq.to_curl()
    end

    test "req compression option" do
      assert "curl --compressed -X GET https://example.com" ==
               Req.new(url: "https://example.com", compressed: true)
               |> CurlReq.to_curl()
    end

    test "req flavor with explicit headers" do
      assert "curl -H \"accept-encoding: gzip\" -H \"user-agent: req/#{req_version()}\" -X GET https://example.com" ==
               Req.new(url: "https://example.com")
               |> CurlReq.to_curl(flavor: :req)
    end

    test "proxy" do
      assert ~S(curl --compressed -x "http://my.proxy.com:80" -X GET https://example.com) ==
               Req.new(
                 url: "https://example.com",
                 connect_options: [proxy: {:http, "my.proxy.com", 80, []}]
               )
               |> CurlReq.to_curl()
    end

    test "proxy user" do
      assert ~S(curl --compressed -x "http://my.proxy.com:80" -U foo:bar -X GET https://example.com) ==
               Req.new(
                 url: "https://example.com",
                 connect_options: [
                   proxy: {:http, "my.proxy.com", 80, []},
                   proxy_headers: [
                     {"proxy-authorization", "Basic " <> Base.encode64("foo:bar")}
                   ]
                 ]
               )
               |> CurlReq.to_curl()
    end

    test "basic auth option" do
      assert "curl -u user:pass --basic --compressed -X GET https://example.com" ==
               Req.new(url: "https://example.com", auth: {:basic, "user:pass"})
               |> CurlReq.to_curl()
    end

    test "bearer auth option" do
      assert ~S(curl -H "authorization: Bearer foo123bar" --compressed -X GET https://example.com) ==
               Req.new(url: "https://example.com", auth: {:bearer, "foo123bar"})
               |> CurlReq.to_curl()
    end

    @tag :tmp_dir
    test "netrc auth option", %{tmp_dir: tmp_dir} do
      credentials =
        """
        machine example.com
          login foo
          password bar
        """

      netrc_path = Path.join(tmp_dir, "my_netrc")
      File.write(netrc_path, credentials)
      System.put_env("NETRC", netrc_path)

      assert "curl -n --compressed -X GET https://example.com" ==
               Req.new(url: "https://example.com", auth: :netrc)
               |> CurlReq.to_curl()
    end

    @tag :tmp_dir
    test "netrc file auth option", %{tmp_dir: tmp_dir} do
      credentials =
        """
        machine example.com
          login foo
          password bar
        """

      netrc_path = Path.join(tmp_dir, "my_netrc")
      File.write(netrc_path, credentials)

      assert ~s(curl --netrc-file "#{netrc_path}" --compressed -X GET https://example.com) ==
               Req.new(url: "https://example.com", auth: {:netrc, netrc_path})
               |> CurlReq.to_curl()
    end

    test "include `encode_body` does not run `comporessed` or other steps" do
      assert ~S(curl -H "accept: application/json" -H "content-type: application/json" -d "{\"key\":\"val\"}" -X GET https://example.com) ==
               Req.new(url: "https://example.com", json: %{key: "val"})
               |> CurlReq.to_curl(run_steps: [only: [:encode_body]])
    end

    test "exclude `compressed` and `encode_body` do not run" do
      assert "curl -X GET https://example.com" ==
               Req.new(url: "https://example.com", json: %{key: "val"})
               |> CurlReq.to_curl(run_steps: [except: [:compressed, :encode_body]])
    end
  end
end
