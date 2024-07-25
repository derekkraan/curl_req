defmodule CurlReq.MacroTest do
  use ExUnit.Case, async: true

  import CurlReq

  describe "macro" do
    test "single header" do
      assert ~CURL(curl -H "user-agent: req/0.4.14" -X GET https://catfact.ninja/fact) ==
               %Req.Request{
                 method: :get,
                 headers: %{"user-agent" => ["req/0.4.14"]},
                 url: URI.parse("https://catfact.ninja/fact")
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
                 headers: %{
                   "accept-encoding" => ["gzip"],
                   "content-type" => ["application/json"],
                   "user-agent" => ["req/0.4.14"]
                 },
                 registered_options: MapSet.new([:auth]),
                 options: %{auth: {:bearer, "6e8f18e6-141b-4d12-8397-7e7791d92ed4:lon"}},
                 current_request_steps: [:auth],
                 request_steps: [auth: &Req.Steps.auth/1],
                 body:
                   "{\"input\":[{\"leadFormFields\":{\"Company\":\"k\",\"Country\":\"DZ\",\"Email\":\"k\",\"FirstName\":\"k\",\"Industry\":\"CTO\",\"LastName\":\"k\",\"Phone\":\"k\",\"PostalCode\":\"1234ZZ\",\"jobspecialty\":\"engineer\",\"message\":\"I would like to know if Roche delivers to The Netherlands.\"}}],\"formId\":4318}"
               }
    end

    test "without curl prefix" do
      assert ~CURL(http://localhost) ==
               %Req.Request{
                 method: :get,
                 url: URI.parse("http://localhost")
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
                 headers: %{"cookie" => ["name1=value1; name2=value2"]}
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
        https://api.github.com/users
      """

      assert curl ==
               %Req.Request{
                 url: URI.parse("https://api.github.com/users"),
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
      uri = URI.parse("https://hello.myshopify.com/api/2024-07/graphql.json")

      assert %Req.Request{
               method: :post,
               url: ^uri,
               headers: %{"content-type" => ["application/json"]}
             } = ~CURL"""
                 curl -X POST \
                   https://hello.myshopify.com/api/2024-07/graphql.json \
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
               headers: %{"content-type" => ["application/json"]}
             } = ~CURL"""
                 curl -X POST
                   https://hello.myshopify.com/api/2024-07/graphql.json
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
  end
end
