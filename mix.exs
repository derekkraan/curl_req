defmodule CurlReq.MixProject do
  use Mix.Project

  def project do
    [
      app: :curl_req,
      version: "0.98.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.4.0 or ~> 0.5.0"},
      {:ex_doc, ">= 0.0.0"}
    ]
  end
end
