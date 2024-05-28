defmodule CurlReqTest do
  use ExUnit.Case
  doctest CurlReq

  test "greets the world" do
    assert CurlReq.hello() == :world
  end
end
