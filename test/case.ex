defmodule CurlReq.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import CurlReq.Assertions
    end
  end
end
