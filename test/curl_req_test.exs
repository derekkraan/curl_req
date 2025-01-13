defmodule CurlReqTest do
  use ExUnit.Case, async: true

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
               ~S|curl --compressed --header "content-type: application/json" --cookie "name1=value1" --location --head http://example.com|
    end

    test "formdata flags get set with correct headers and body" do
      assert Req.new(url: "http://example.com", form: [key1: "value1", key2: "value2"])
             |> CurlReq.to_curl() ==
               ~S|curl --compressed -H "content-type: application/x-www-form-urlencoded" -d "key1=value1&key2=value2" -X GET http://example.com|
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
  end

  describe "from_curl" do
    test "no scheme in url defaults to http" do
      assert ~CURL(curl example.com/fact) ==
               %Req.Request{
                 method: :get,
                 url: URI.parse("http://example.com/fact")
               }
    end

    test "wrong scheme raises error" do
      assert_raise(
        ArgumentError,
        "Unsupported scheme ftp for URL in ftp://example.com/fact",
        fn -> CurlReq.from_curl(~s"curl ftp://example.com/fact") end
      )
    end

    test "single header" do
      assert ~CURL(curl -H "user-agent: req/0.4.14" -X GET https://example.com/fact) ==
               %Req.Request{
                 method: :get,
                 url: URI.parse("https://example.com/fact")
               }
    end

    test "post method" do
      assert ~CURL(curl -X POST https://example.com) ==
               %Req.Request{
                 method: :post,
                 url: URI.parse("https://example.com")
               }
    end

    test "head method" do
      assert ~CURL(curl -I https://example.com) ==
               %Req.Request{
                 method: :head,
                 url: URI.parse("https://example.com")
               }
    end

    test "multiple headers with body" do
      assert ~CURL(curl -H "accept-encoding: gzip" -H "authorization: Bearer 6e8f18e6-141b-4d12-8397-7e7791d92ed4:lon" -H "content-type: application/json" -H "user-agent: req/0.4.14" -d "{\"input\":[{\"leadFormFields\":{\"Company\":\"k\",\"Country\":\"DZ\",\"Email\":\"k\",\"FirstName\":\"k\",\"Industry\":\"CTO\",\"LastName\":\"k\",\"Phone\":\"k\",\"PostalCode\":\"1234ZZ\",\"jobspecialty\":\"engineer\",\"message\":\"I would like to know if Roche delivers to The Netherlands.\"}}],\"formId\":4318}" -X POST "https://example.com/rest/v1/leads/submitForm.json") ==
               %Req.Request{
                 method: :post,
                 url: URI.parse("https://example.com/rest/v1/leads/submitForm.json"),
                 registered_options: MapSet.new([:compressed, :auth, :json]),
                 options: %{
                   compressed: true,
                   auth: {:bearer, "6e8f18e6-141b-4d12-8397-7e7791d92ed4:lon"},
                   json: %{
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
                           "message" =>
                             "I would like to know if Roche delivers to The Netherlands."
                         }
                       }
                     ]
                   }
                 },
                 current_request_steps: [:compressed, :auth, :encode_body],
                 request_steps: [
                   compressed: &Req.Steps.compressed/1,
                   auth: &Req.Steps.auth/1,
                   encode_body: &Req.Steps.encode_body/1
                 ]
               }
    end

    test "without curl prefix" do
      assert ~CURL(http://example.com) ==
               %Req.Request{
                 method: :get,
                 url: URI.parse("http://example.com")
               }
    end

    test "multiple data flags" do
      assert ~CURL(curl http://example.com -d name=foo -d mail=bar) ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 body: "name=foo&mail=bar"
               }
    end

    test "cookie" do
      assert ~CURL(http://example.com -b "name1=value1") ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 headers: %{"cookie" => ["name1=value1"]}
               }

      assert ~CURL(http://example.com -b "name1=value1; name2=value2") ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 headers: %{"cookie" => ["name1=value1;name2=value2"]}
               }
    end

    test "formdata" do
      assert ~CURL(curl http://example.com -F name=foo -F mail=bar) ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 body: nil,
                 registered_options: MapSet.new([:form]),
                 options: %{form: %{"name" => "foo", "mail" => "bar"}},
                 current_request_steps: [:encode_body],
                 request_steps: [encode_body: &Req.Steps.encode_body/1]
               }
    end

    test "data raw" do
      assert ~CURL"""
             curl 'https://example.com/graphql' \
             -X POST \
             -H 'Accept: application/graphql-response+json'\
             --data-raw '{"operationName":"get","query":"query get {name}"}'
             """ ==
               %Req.Request{
                 method: :post,
                 url: URI.parse("https://example.com/graphql"),
                 headers: %{"accept" => ["application/graphql-response+json"]},
                 body: "{\"operationName\":\"get\",\"query\":\"query get {name}\"}",
                 options: %{},
                 halted: false,
                 adapter: &Req.Steps.run_finch/1,
                 request_steps: [],
                 response_steps: [],
                 error_steps: [],
                 private: %{}
               }
    end

    test "data raw with ansii escape" do
      assert ~CURL"""
             curl 'https://example.com/employees/107'\
             -X PATCH\
             -H 'Accept: application/vnd.api+json'\
             --data-raw $'{"data":{"attributes":{"first-name":"Adam"}}}'
             """ ==
               %Req.Request{
                 method: :patch,
                 url: URI.parse("https://example.com/employees/107"),
                 headers: %{"accept" => ["application/vnd.api+json"]},
                 body: "{\"data\":{\"attributes\":{\"first-name\":\"Adam\"}}}",
                 options: %{},
                 halted: false,
                 adapter: &Req.Steps.run_finch/1,
                 request_steps: [],
                 response_steps: [],
                 error_steps: [],
                 private: %{}
               }
    end

    test "auth" do
      assert ~CURL(curl http://example.com -u user:pass) ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 body: nil,
                 registered_options: MapSet.new([:auth]),
                 options: %{auth: {:basic, "user:pass"}},
                 current_request_steps: [:auth],
                 request_steps: [auth: &Req.Steps.auth/1]
               }
    end

    test "bearer token auth" do
      curl = ~CURL"""
        curl -L \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer <YOUR-TOKEN>" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://example.com/users
      """

      assert curl ==
               %Req.Request{
                 url: URI.parse("https://example.com/users"),
                 body: nil,
                 headers: %{
                   "accept" => ["application/vnd.github+json"],
                   "x-github-api-version" => ["2022-11-28"]
                 },
                 registered_options: MapSet.new([:auth, :redirect]),
                 options: %{auth: {:bearer, "<YOUR-TOKEN>"}, redirect: true},
                 current_request_steps: [:auth],
                 request_steps: [auth: &Req.Steps.auth/1],
                 response_steps: [redirect: &Req.Steps.redirect/1]
               }
    end

    test "compressed" do
      assert ~CURL(curl --compressed http://example.com) ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 body: nil,
                 registered_options: MapSet.new([:compressed]),
                 options: %{compressed: true},
                 current_request_steps: [:compressed],
                 request_steps: [compressed: &Req.Steps.compressed/1]
               }
    end

    test "redirect" do
      assert ~CURL(curl -L http://example.com) ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 registered_options: MapSet.new([:redirect]),
                 options: %{redirect: true},
                 response_steps: [redirect: &Req.Steps.redirect/1]
               }
    end

    test "cookie, formadata, auth and redirect" do
      assert ~CURL(curl -L -u user:pass -F name=foo -b name=bar http://example.com) ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 headers: %{"cookie" => ["name=bar"]},
                 current_request_steps: [:auth, :encode_body],
                 registered_options: MapSet.new([:redirect, :auth, :form]),
                 options: %{redirect: true, auth: {:basic, "user:pass"}, form: %{"name" => "foo"}},
                 request_steps: [auth: &Req.Steps.auth/1, encode_body: &Req.Steps.encode_body/1],
                 response_steps: [redirect: &Req.Steps.redirect/1]
               }
    end

    test "proxy" do
      assert ~CURL(curl --proxy my.proxy.com:22225 http://example.com) ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 registered_options: MapSet.new([:connect_options]),
                 options: %{
                   connect_options: [proxy: {:http, "my.proxy.com", 22225, []}]
                 }
               }
    end

    test "proxy with basic auth" do
      assert ~CURL(curl --proxy https://my.proxy.com:22225 --proxy-user foo:bar http://example.com) ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 registered_options: MapSet.new([:connect_options]),
                 options: %{
                   connect_options: [
                     proxy: {:https, "my.proxy.com", 22225, []},
                     proxy_headers: [
                       {"proxy-authorization", "Basic " <> Base.encode64("foo:bar")}
                     ]
                   ]
                 }
               }
    end

    test "proxy with inline basic auth" do
      assert ~CURL(curl --proxy https://foo:bar@my.proxy.com:22225 http://example.com) ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 registered_options: MapSet.new([:connect_options]),
                 options: %{
                   connect_options: [
                     proxy: {:https, "my.proxy.com", 22225, []},
                     proxy_headers: [
                       {"proxy-authorization", "Basic " <> Base.encode64("foo:bar")}
                     ]
                   ]
                 }
               }
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
      assert ~CURL(curl -k http://example.com) ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 registered_options: MapSet.new([:connect_options]),
                 options: %{
                   connect_options: [
                     transport_opts: [verify: :verify_none]
                   ]
                 }
               }

      assert ~CURL(curl --insecure http://example.com) ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 registered_options: MapSet.new([:connect_options]),
                 options: %{
                   connect_options: [
                     transport_opts: [verify: :verify_none]
                   ]
                 }
               }
    end

    test "insecure flag with proxy" do
      assert ~CURL(curl -k --proxy my.proxy.com:2233 http://example.com) ==
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
    end

    test "user agent flag" do
      assert ~CURL(curl -A "some_user_agent/0.1.0" http://example.com) ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 headers: %{"user-agent" => ["some_user_agent/0.1.0"]}
               }

      assert ~CURL(curl --user-agent "some_user_agent/0.1.0" http://example.com) ==
               %Req.Request{
                 url: URI.parse("http://example.com"),
                 headers: %{"user-agent" => ["some_user_agent/0.1.0"]}
               }
    end
  end

  describe "newlines" do
    test "sigil_CURL supports newlines" do
      curl = ~CURL"""
        curl -X POST \
         --location \
         https://example.com
      """

      assert curl == %Req.Request{
               method: :post,
               url: URI.parse("https://example.com"),
               registered_options: MapSet.new([:redirect]),
               options: %{redirect: true},
               response_steps: [redirect: &Req.Steps.redirect/1]
             }
    end

    test "from_curl supports newlines" do
      curl =
        from_curl("""
          curl -X POST \
           --location \
           https://example.com
        """)

      assert curl == %Req.Request{
               method: :post,
               url: URI.parse("https://example.com"),
               registered_options: MapSet.new([:redirect]),
               options: %{redirect: true},
               response_steps: [redirect: &Req.Steps.redirect/1]
             }
    end

    test "accepts newlines ending in backslash" do
      uri = URI.parse("https://example.com/api/2024-07/graphql.json")

      assert %Req.Request{
               method: :post,
               url: ^uri,
               options: %{json: %{"query" => _}}
             } = ~CURL"""
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

      assert %Req.Request{
               method: :post,
               url: ^uri,
               options: %{json: %{"query" => _}}
             } = ~CURL"""
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
    end

    test "unused flags get ignored" do
      # we don't need an assertion because if we couldn't parse the flag we would throw an exception and the test would fail
      CurlReq.Curl.decode(~s(curl -o "somefile" https://example.com))
      CurlReq.Curl.decode(~s(curl -O https://example.com))
      CurlReq.Curl.decode(~s(curl -s https://example.com))
      CurlReq.Curl.decode(~s(curl -S https://example.com))
      CurlReq.Curl.decode(~s(curl -f https://example.com))
      CurlReq.Curl.decode(~s(curl -fsS https://example.com))
    end

    test "raises on unsupported flag" do
      assert_raise ArgumentError, ~r/Unknown "--foo"/, fn ->
        CurlReq.Curl.decode(~s(curl --foo https://example.com))
      end
    end
  end
end
