defmodule CurlReqTest do
  use CurlReq.Case, async: true

  doctest CurlReq, import: true

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
      assert capture_io(:stdio, fn ->
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

    test "escape url when needed" do
      assert ~s(curl --compressed -X GET "https://example.com/fact?") ==
               Req.new(url: "/fact?", base_url: "https://example.com/")
               |> CurlReq.to_curl()
    end

    test "cookies get extracted from header" do
      assert Req.new(url: "http://example.com", headers: %{"cookie" => ["name1=value1"]})
             |> CurlReq.to_curl() ==
               ~s|curl --compressed -b "name1=value1" -X GET http://example.com|
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
               ~S|curl --compressed --cookie "name1=value1" --location --head http://example.com|

      # header get's removed because body is empty
    end

    test "formdata flags get set with correct headers and body" do
      assert Req.new(url: "http://example.com", form: [key1: "value1", key2: "value2"])
             |> CurlReq.to_curl() ==
               ~S|curl --compressed -H "content-type: application/x-www-form-urlencoded" -d "key1=value1&key2=value2" -X GET http://example.com|
    end

    test "works when body is iodata" do
      assert ~s|curl --compressed -H "content-type: text/plain" -d hello -X POST https://example.com/fact| ==
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

    test "header" do
      assert ~s(curl --compressed -H "my-header: foo" -X GET https://example.com) ==
               Req.new(url: "https://example.com", headers: %{"my-header" => ["foo"]})
               |> CurlReq.to_curl()
    end

    test "parameterized header" do
      assert ~s(curl --compressed -H "my-header: foo, bar=baz" -X GET https://example.com) ==
               Req.new(url: "https://example.com", headers: %{"my-header" => ["foo", "bar=baz"]})
               |> CurlReq.to_curl()
    end

    test "req flavor with explicit headers" do
      assert ~s|curl -H "accept-encoding: gzip" -A "req/#{req_version()}" -X GET https://example.com| ==
               Req.new(url: "https://example.com")
               |> CurlReq.to_curl(flavor: :req)
    end

    test "proxy" do
      assert ~S(curl --compressed -x http://my.proxy.com -X GET https://example.com) ==
               Req.new(
                 url: "https://example.com",
                 connect_options: [proxy: {:http, "my.proxy.com", 80, []}]
               )
               |> CurlReq.to_curl()
    end

    test "proxy user" do
      assert ~S(curl --compressed -x http://my.proxy.com -U foo:bar -X GET https://example.com) ==
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
      assert "curl --compressed -u user:pass -X GET https://example.com" ==
               Req.new(url: "https://example.com", auth: {:basic, "user:pass"})
               |> CurlReq.to_curl()
    end

    test "bearer auth option" do
      assert ~S(curl --compressed -H "authorization: Bearer foo123bar" -X GET https://example.com) ==
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

      assert "curl --compressed -n -X GET https://example.com" ==
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

      assert ~s(curl --compressed --netrc-file "#{netrc_path}" -X GET https://example.com) ==
               Req.new(url: "https://example.com", auth: {:netrc, netrc_path})
               |> CurlReq.to_curl()
    end

    test "include `encode_body` does not run `compressed` or other steps" do
      assert ~S(curl -H "accept: application/json" -H "content-type: application/json" -d "{\"key\":\"val\"}" -X GET https://example.com) ==
               Req.new(url: "https://example.com", json: %{key: "val"})
               |> CurlReq.to_curl(run_steps: [only: [:encode_body]])
    end

    test "exclude `compressed` and `encode_body` do not run" do
      assert "curl -X GET https://example.com" ==
               Req.new(url: "https://example.com", json: %{key: "val"})
               |> CurlReq.to_curl(run_steps: [except: [:compressed, :encode_body]])
    end

    test "insecure flag" do
      assert ~s(curl -k -X GET http://example.com) ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 registered_options: MapSet.new([:connect_options]),
                 options: %{
                   connect_options: [
                     transport_opts: [verify: :verify_none]
                   ]
                 }
               }
               |> CurlReq.to_curl()
    end

    test "insecure flag with proxy" do
      assert ~s(curl -k -x "http://my.proxy.com:2233" -X GET http://example.com) ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 registered_options: MapSet.new([:connect_options]),
                 options: %{
                   connect_options: [
                     proxy: {:http, "my.proxy.com", 2233, []},
                     transport_opts: [verify: :verify_none]
                   ]
                 }
               }
               |> CurlReq.to_curl()
    end

    test "user agent flag" do
      assert ~s(curl --compressed -A "some_user_agent/0.1.0" -X GET http://example.com) ==
               Req.new(
                 url: "http://example.com",
                 headers: %{"user-agent" => ["some_user_agent/0.1.0"]}
               )
               |> CurlReq.to_curl()

      assert ~s(curl --compressed --user-agent "some_user_agent/0.1.0" --request GET http://example.com) ==
               Req.new(
                 url: "http://example.com",
                 headers: %{"user-agent" => ["some_user_agent/0.1.0"]}
               )
               |> CurlReq.to_curl(flags: :long)
    end

    test "protocols" do
      assert ~s(curl --compressed -0 --http1.1 -X GET http://example.com) ==
               Req.new(
                 url: "http://example.com",
                 connect_options: [protocols: [:http1]]
               )
               |> CurlReq.to_curl()

      assert ~s(curl --compressed -X GET http://example.com) ==
               Req.new(
                 url: "http://example.com",
                 connect_options: [protocols: [:http2]]
               )
               |> CurlReq.to_curl()

      assert ~s(curl --compressed -X GET http://example.com) ==
               Req.new(
                 url: "http://example.com",
                 connect_options: [protocols: [:http1, :http2]]
               )
               |> CurlReq.to_curl()
    end
  end

  describe "from_curl" do
    test "no scheme in url defaults to http" do
      ~CURL(curl example.com/fact)
      |> assert_url("http://example.com/fact")
    end

    test "redirect and compression is false by default" do
      ~CURL(curl example.com/fact)
      |> assert_url("http://example.com/fact")
      |> assert_redirect(false)
      |> assert_compressed(false)
    end

    test "wrong scheme raises error" do
      assert_raise(
        ArgumentError,
        "Unsupported scheme ftp for URL in ftp://example.com/fact",
        fn -> CurlReq.from_curl(~s"curl ftp://example.com/fact") end
      )
    end

    test "single header" do
      ~CURL(curl -H "foo: bar" -X GET https://example.com/fact)
      |> assert_header("foo", ["bar"])
    end

    test "post method" do
      ~CURL(curl -X POST https://example.com)
      |> assert_method(:post)
    end

    test "head method" do
      ~CURL(curl -I https://example.com)
      |> assert_method(:head)
    end

    test "raw body" do
      ~CURL(curl -d foo https://example.com)
      |> assert_form(%{"foo" => ""})
    end

    test "form body" do
      ~CURL(curl -d foo=bar https://example.com)
      |> assert_form(%{"foo" => "bar"})

      ~CURL(curl -d foo=bar&baz=qux https://example.com)
      |> assert_form(%{"foo" => "bar", "baz" => "qux"})
    end

    test "form body with multiple data flags" do
      ~CURL(curl http://example.com -d name=foo -d mail=bar)
      |> assert_form(%{"name" => "foo", "mail" => "bar"})
    end

    test "json body" do
      ~CURL(curl -H "content-type: application/json" -d "{\"foo\": \"bar\"}" https://example.com)
      |> assert_json(%{"foo" => "bar"})
    end

    test "content-type with parameter" do
      ~CURL(curl -H "content-type: application/json; charset=utf-8" -d '{"foo": "bar"}' https://example.com)
      |> assert_json(%{"foo" => "bar"})
    end

    test "multiple header" do
      ~CURL(curl -H "my-header: foo, bar=baz" https://example.com)
      |> assert_header("my-header", ["foo, bar=baz"])
    end

    test "complex cookie" do
      ~CURL(curl --header 'Cookie: TealeafAkaSid=JA-JSAXRCLjKYhjV9IXTzYUbcV1Lnhqf; sapphire=1; visitorId=0184E4601D5A020183FFBB133 80347CE; GuestLocation=33196|25.660|-80.440|FL|US' -X GET https://example.com)
      |> assert_cookie("TealeafAkaSid=JA-JSAXRCLjKYhjV9IXTzYUbcV1Lnhqf")
      |> assert_cookie("sapphire=1")
      |> assert_cookie("visitorId=0184E4601D5A020183FFBB133 80347CE")
      |> assert_cookie("GuestLocation=33196|25.660|-80.440|FL|US")
    end

    test "multiple headers with body" do
      ~CURL(curl -H "accept-encoding: gzip" -H "authorization: Bearer 6e8f18e6-141b-4d12-8397-7e7791d92ed4:lon" -H "content-type: application/json" -H "user-agent: req/0.4.14" -d "{\"input\":[{\"leadFormFields\":{\"Company\":\"k\",\"Country\":\"DZ\",\"Email\":\"k\",\"FirstName\":\"k\",\"Industry\":\"CTO\",\"LastName\":\"k\",\"Phone\":\"k\",\"PostalCode\":\"1234ZZ\",\"jobspecialty\":\"engineer\",\"message\":\"I would like to know if Roche delivers to The Netherlands.\"}}],\"formId\":4318}" -X POST "https://example.com/rest/v1/leads/submitForm.json")
      |> assert_url("https://example.com/rest/v1/leads/submitForm.json")
      |> assert_method(:post)
      |> assert_compressed()
      |> assert_auth(:bearer, "6e8f18e6-141b-4d12-8397-7e7791d92ed4:lon")
      |> assert_json(%{
        "formId" => 4318,
        "input" => [
          %{
            "leadFormFields" => %{
              "Company" => "k",
              "Country" => "DZ",
              "Email" => "k",
              "FirstName" => "k",
              "Industry" => "CTO",
              "LastName" => "k",
              "Phone" => "k",
              "PostalCode" => "1234ZZ",
              "jobspecialty" => "engineer",
              "message" => "I would like to know if Roche delivers to The Netherlands."
            }
          }
        ]
      })
    end

    test "without curl prefix" do
      ~CURL(http://example.com)
      |> assert_url("http://example.com")
    end

    test "cookie" do
      ~CURL(http://example.com -b "name1=value1")
      |> assert_cookie("name1=value1")

      ~CURL(http://example.com -b "name1=value1; name2=value2")
      |> assert_cookie("name1=value1")
      |> assert_cookie("name2=value2")
    end

    test "formdata" do
      ~CURL(curl http://example.com -F name=foo -F mail=bar)
      |> assert_form(%{"name" => "foo", "mail" => "bar"})
    end

    test "data raw" do
      ~CURL"""
      curl 'https://example.com/graphql' \
      -X POST \
      -H 'Accept: application/graphql-response+json'\
      -H 'Content-Type: application/json' \
      --data-raw '{"operationName":"get","query":"query get {name}"}'
      """
      |> assert_method(:post)
      |> assert_url("https://example.com/graphql")
      |> assert_header("accept", ["application/graphql-response+json"])
      |> assert_json(%{"operationName" => "get", "query" => "query get {name}"})
    end

    test "data raw with ansii escape" do
      ~CURL"""
      curl 'https://example.com/employees/107'\
      -X PATCH\
      -H 'Content-Type: application/json' \
      -H 'Accept: application/vnd.api+json'\
      --data-raw $'{"data":{"attributes":{"first-name":"Adam"}}}'
      """
      |> assert_method(:patch)
      |> assert_url("https://example.com/employees/107")
      |> assert_header("accept", ["application/vnd.api+json"])
      |> assert_json(%{"data" => %{"attributes" => %{"first-name" => "Adam"}}})
    end

    test "auth" do
      ~CURL(curl http://example.com -u user:pass)
      |> assert_auth(:basic, "user:pass")
    end

    test "bearer token auth" do
      ~CURL"""
        curl -L \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer <YOUR-TOKEN>" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://example.com/users
      """
      |> assert_header("accept", ["application/vnd.github+json"])
      |> assert_header("x-github-api-version", ["2022-11-28"])
      |> assert_auth(:bearer, "<YOUR-TOKEN>")
      |> assert_redirect()
    end

    test "compressed" do
      ~CURL(curl --compressed http://example.com)
      |> assert_compressed()
    end

    test "redirect" do
      ~CURL(curl -L http://example.com)
      |> assert_redirect()

      ~CURL(curl --location http://example.com)
      |> assert_redirect()
    end

    test "cookie, formadata, auth and redirect" do
      ~CURL(curl -L -u user:pass -F name=foo -b name=bar http://example.com)
      |> assert_redirect()
      |> assert_auth(:basic, "user:pass")
      |> assert_form(%{"name" => "foo"})
      |> assert_cookie("name=bar")
    end

    test "proxy" do
      ~CURL(curl --proxy my.proxy.com:22225 http://example.com)
      |> assert_proxy(:http, "my.proxy.com", 22225)
    end

    test "proxy with basic auth" do
      ~CURL(curl --proxy https://my.proxy.com:22225 --proxy-user foo:bar http://example.com)
      |> assert_proxy(:https, "my.proxy.com", 22225)
      |> assert_auth(:proxy, "foo:bar")
    end

    test "proxy with inline basic auth" do
      ~CURL(curl --proxy https://foo:bar@my.proxy.com:22225 http://example.com)
      |> assert_proxy(:https, "my.proxy.com", 22225)
      |> assert_auth(:proxy, "foo:bar")
    end

    test "proxy raises on non http scheme uri" do
      assert_raise(
        ArgumentError,
        "Unsupported scheme ssh for URL in ssh://my.proxy.com:22225",
        fn ->
          CurlReq.Curl.decode("curl --proxy ssh://my.proxy.com:22225 http://example.com")
        end
      )
    end

    test "insecure flag" do
      assert_insecure(~CURL(curl -k http://example.com))
      assert_insecure(~CURL(curl --insecure http://example.com))
    end

    test "insecure flag with proxy" do
      ~CURL(curl -k --proxy my.proxy.com:2233 http://example.com)
      |> assert_insecure()
      |> assert_proxy(:http, "my.proxy.com", 2233)
    end

    test "user agent flag" do
      ~CURL(curl -A "some_user_agent/0.1.0" http://example.com)
      |> assert_header("user-agent", ["some_user_agent/0.1.0"])

      ~CURL(curl --user-agent "some_user_agent/0.1.0" http://example.com)
      |> assert_header("user-agent", ["some_user_agent/0.1.0"])
    end

    test "protocols flag" do
      ~CURL(curl --http1.0 -X GET http://example.com)
      |> assert_protocol(:http1)

      ~CURL(curl --http1.1 -X GET http://example.com)
      |> assert_protocol(:http1)

      ~CURL(curl --http2 -X GET http://example.com)
      |> assert_protocol(:http2)

      ~CURL(curl --http1.1 --http2 -X GET http://example.com)
      |> assert_protocol(:http1)
      |> assert_protocol(:http2)
    end
  end

  describe "newlines" do
    test "sigil_CURL supports newlines" do
      ~CURL"""
        curl -X POST \
         --location \
         https://example.com
      """
      |> assert_redirect()
      |> assert_method(:post)
      |> assert_url("https://example.com")
    end

    test "from_curl supports newlines" do
      from_curl("""
        curl -X POST \
         --location \
         https://example.com
      """)
      |> assert_redirect()
      |> assert_method(:post)
      |> assert_url("https://example.com")
    end

    test "accepts newlines ending in backslash" do
      ~CURL"""
          curl -X POST \
            https://example.com/api/2024-07/graphql.json \
            -H 'Content-Type: application/json' \
            -H 'X-Shopify-Storefront-Access-Token: ABCDEF' \
            -d '{
              "query": "{
                products(first: 3) {
                  edges {
                    node {
                      id
                      title
                    }
                  }
                }
              }"
            }'
      """
      |> assert_url("https://example.com/api/2024-07/graphql.json")
      |> assert_header("X-Shopify-Storefront-Access-Token", ["ABCDEF"])

      ~CURL"""
          curl -X POST
            https://example.com/api/2024-07/graphql.json
            -H 'Content-Type: application/json'
            -H 'X-Shopify-Storefront-Access-Token: ABCDEF'
            -d '{
              "query": "{
                products(first: 3) {
                  edges {
                    node {
                      id
                      title
                    }
                  }
                }
              }"
            }'
      """
      |> assert_header("X-Shopify-Storefront-Access-Token", ["ABCDEF"])
      |> assert_url("https://example.com/api/2024-07/graphql.json")
    end

    test "unused flags get ignored" do
      # we don't need an assertion because if we couldn't parse the flag we would throw an exception and the test would fail
      CurlReq.Curl.decode(~s(curl -o "somefile" https://example.com))
      CurlReq.Curl.decode(~s(curl -O https://example.com))
      CurlReq.Curl.decode(~s(curl -s https://example.com))
      CurlReq.Curl.decode(~s(curl -S https://example.com))
      CurlReq.Curl.decode(~s(curl -f https://example.com))
      CurlReq.Curl.decode(~s(curl -fsS https://example.com))
      CurlReq.Curl.decode(~s(curl -v https://example.com))
      CurlReq.Curl.decode(~s(curl -vvv https://example.com))
      CurlReq.Curl.decode(~s(curl --verbose https://example.com))
    end

    test "raises on unsupported flag" do
      assert_raise ArgumentError, ~r/Unknown "--foo"/, fn ->
        CurlReq.Curl.decode(~s(curl --foo https://example.com))
      end
    end
  end
end
