defmodule CurlReqTest do
  use ExUnit.Case
  doctest CurlReq

  test "works with base URL" do
    assert "curl" ==
             Req.new(url: "/fact", base_url: "https://catfact.ninja/")
             |> CurlReq.inspect(label: "REQUEST")
  end

  # test "greets the world" do
  #   assert CurlReq.hello() == :world
  # end
end
