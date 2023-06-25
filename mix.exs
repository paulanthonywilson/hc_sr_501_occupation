defmodule HcSr501Occupation.MixProject do
  use Mix.Project

  def project do
    [
      app: :hc_sr_501_occupation,
      version: "0.1.3",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test]},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.29.1", only: :dev, runtime: false},
      {:circuits_gpio, "~> 1.1"},
      {:simplest_pub_sub, "~> 0.1"}
    ]
  end

  defp package do
    [
      description:
        "For HC_SR_501 sensores. Detects movemement and determine small-room occupancy.",
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/paulanthonywilson/hc_sr_501_occupation"}
    ]
  end

  defp docs do
    [main: "readme", extras: ["README.md", "CHANGELOG.md"]]
  end
end
