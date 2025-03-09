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
      version: "0.100.0"
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
      {:jason, "~> 1.4"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:blend, "~> 0.4.1", only: :dev},
      {:plug, "~> 1.16"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "guides/usage.livemd", "guides/cheatsheet.cheatmd"],
      groups_for_extras: [Guides: Path.wildcard("guides/*")]
    ]
  end

  defp package() do
    [
      description: "Req 💗 curl",
      licenses: ["MIT"],
      links: %{GitHub: "https://github.com/derekkraan/curl_req"},
      maintainers: ["Derek Kraan", "Kevin Schweikert"]
    ]
  end
end
