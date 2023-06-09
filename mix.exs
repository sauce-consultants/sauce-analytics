defmodule SauceAnalytics.MixProject do
  use Mix.Project

  def project do
    [
      app: :sauce_analytics,
      version: "0.1.2",
      elixir: "~> 1.14",
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      name: "sauce_analytics",
      source_url: "https://github.com/sauce-consultants/sauce-analytics",
      docs: [
        main: "SauceAnalytics",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :retry, :phoenix_live_view],
      applications: applications(Mix.env())
    ]
  end

  defp applications(:test), do: applications(:default) ++ [:cowboy, :plug, :jason, :bypass]
  defp applications(_), do: [:httpoison, :phoenix_live_view]


  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:plug_cowboy, "~> 2.0", runtime: false},
      {:phoenix_live_view, "~> 0.18", runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:retry, "~> 0.17"},
      {:httpoison, "~> 2.0"},
      {:jason, "~> 1.0", only: [:dev, :test]},
      {:bypass, "~> 2.1", only: :test}
    ]
  end

  defp description do
    """
    Phoenix library for using the Sauce Analytics API
    """
  end

  defp package() do
    [
      maintainers: ["Alan Strauhs"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/sauce-consultants/sauce-analytics"}
    ]
  end
end
