defmodule CurlReq.MixProject do
  use Mix.Project

  def project do
    [
      app: :curl_req,
      deps: deps(),
      docs: docs(),
      elixir: "~> 1.15",
      name: "CurlReq",
      package: package(),
      source_url: "https://github.com/derekkraan/curl_req",
      start_permanent: Mix.env() == :prod,
      version: "0.98.4"
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
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp docs do
    [main: "CurlReq", extras: extras()]
  end

  defp extras, do: []

  defp package() do
    [
      description: "Req 💗 curl",
      licenses: ["MIT"],
      links: %{GitHub: "https://github.com/derekkraan/curl_req"},
      maintainers: ["Derek Kraan"]
    ]
  end
end
