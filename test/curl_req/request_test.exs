defmodule CurlReq.RequestTest do
  use ExUnit.Case, async: true
  doctest CurlReq.Request

  alias CurlReq.Request
  import CurlReq.Request

  describe "put_body/2" do
    test "decode form" do
      request =
        %Request{}
        |> put_encoding(:form)
        |> put_body("foo=bar")

      assert %{"foo" => "bar"} = request.body
    end

    test "decode json" do
      request =
        %Request{}
        |> put_encoding(:json)
        |> put_body(~s({"foo":"bar"}))

      assert %{"foo" => "bar"} = request.body
    end
  end

  describe "put_encoding/2" do
    test "raw to form" do
      request =
        %Request{}
        |> put_encoding(:raw)
        |> put_body("foo=bar")
        |> put_encoding(:form)

      assert %{"foo" => "bar"} = request.body
    end

    test "raw to json" do
      request =
        %Request{}
        |> put_encoding(:raw)
        |> put_body(~s({"foo":"bar"}))
        |> put_encoding(:json)

      assert %{"foo" => "bar"} = request.body
    end

    test "form to raw" do
      request =
        %Request{}
        |> put_encoding(:form)
        |> put_body(%{"foo" => "bar"})
        |> put_encoding(:raw)

      assert :raw == request.encoding
      assert "foo=bar" == request.body
    end

    test "json to raw" do
      request =
        %Request{}
        |> put_encoding(:json)
        |> put_body(%{"foo" => "bar"})
        |> put_encoding(:raw)

      assert :raw == request.encoding
      assert ~s({"foo":"bar"}) == request.body
    end

    test "json to form" do
      request =
        %Request{}
        |> put_encoding(:form)
        |> put_body(%{"foo" => "bar"})
        |> put_encoding(:json)

      assert %{"foo" => "bar"} = request.body
    end

    test "from and to same encoding is noop" do
      request =
        %Request{}
        |> put_encoding(:form)
        |> put_body(%{"foo" => "bar"})
        |> put_encoding(:form)
        |> put_encoding(:form)
        |> put_encoding(:form)

      assert %{"foo" => "bar"} = request.body
    end
  end
end
