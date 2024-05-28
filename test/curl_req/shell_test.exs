defmodule CurlReq.ShellTest do
  use ExUnit.Case
  doctest CurlReq.Shell

  test "escapes characters" do
    assert ~S("{\"json\":\"is_cool\"}") == CurlReq.Shell.escape(~s({"json":"is_cool"}))
  end
end
