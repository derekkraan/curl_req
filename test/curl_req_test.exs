defmodule CurlReqTest do
  use ExUnit.Case
  doctest CurlReq
  import CurlReq

  test "works with base URL" do
    assert "curl -H \"accept-encoding: gzip\" -H \"user-agent: req/0.4.14\" -X GET https://catfact.ninja/fact" ==
             Req.new(url: "/fact", base_url: "https://catfact.ninja/")
             |> CurlReq.to_curl()

    ~CURL(curl -H "user-agent: req/0.4.14" -X GET https://catfact.ninja/fact)
    |> Req.request!()

    # ~CURL"""
    # curl -H "accept-encoding: gzip" -H "authorization: Bearer 6e8f18e6-141b-4d12-8397-7e7791d92ed4:lon" -H "content-type: application/json" -H "user-agent: req/0.4.14" -d "{\"input\":[{\"leadFormFields\":{\"Company\":\"k\",\"Country\":\"DZ\",\"Email\":\"k\",\"FirstName\":\"k\",\"Industry\":\"CTO\",\"LastName\":\"k\",\"Phone\":\"k\",\"PostalCode\":\"3544VE\",\"jobspecialty\":\"engineer\",\"message\":\"I would like to know if Roche delivers to Aureliahof16, Utrecht, The Netherlands.\"}}],\"formId\":4318}" -X POST "https://130-RZU-897.mktorest.com/rest/v1/leads/submitForm.json"
    # """
  end
end
