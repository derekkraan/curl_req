defmodule CurlReqTest do
  use ExUnit.Case, async: true
  doctest CurlReq
  import CurlReq

  describe "to_curl" do
    test "works with base URL" do
      assert "curl -H \"accept-encoding: gzip\" -H \"user-agent: req/0.4.14\" -X GET https://catfact.ninja/fact" ==
               Req.new(url: "/fact", base_url: "https://catfact.ninja/")
               |> CurlReq.to_curl()
    end
  end

  describe "macro" do
    test "single header" do
      assert ~CURL(curl -H "user-agent: req/0.4.14" -X GET https://catfact.ninja/fact) ==
               %Req.Request{
                 method: :get,
                 headers: %{"user-agent" => ["req/0.4.14"]},
                 url: URI.parse("https://catfact.ninja/fact")
               }
    end

    test "multiple headers with body" do
      assert ~CURL(curl -H "accept-encoding: gzip" -H "authorization: Bearer 6e8f18e6-141b-4d12-8397-7e7791d92ed4:lon" -H "content-type: application/json" -H "user-agent: req/0.4.14" -d "{\"input\":[{\"leadFormFields\":{\"Company\":\"k\",\"Country\":\"DZ\",\"Email\":\"k\",\"FirstName\":\"k\",\"Industry\":\"CTO\",\"LastName\":\"k\",\"Phone\":\"k\",\"PostalCode\":\"1234ZZ\",\"jobspecialty\":\"engineer\",\"message\":\"I would like to know if Roche delivers to The Netherlands.\"}}],\"formId\":4318}" -X POST "https://example.com/rest/v1/leads/submitForm.json") ==
               %Req.Request{
                 method: :post,
                 url: URI.parse("https://example.com/rest/v1/leads/submitForm.json"),
                 headers: %{
                   "accept-encoding" => ["gzip"],
                   "authorization" => ["Bearer 6e8f18e6-141b-4d12-8397-7e7791d92ed4:lon"],
                   "content-type" => ["application/json"],
                   "user-agent" => ["req/0.4.14"]
                 },
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
  end
end
