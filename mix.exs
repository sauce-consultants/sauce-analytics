defmodule SauceAnalytics.MixProject do
  use Mix.Project

  def project do
    [
      app: :sauce_analytics,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :retry]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:plug_cowboy, "~> 2.0", runtime: false},
      {:phoenix_live_view, "~> 0.18", runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:retry, "~> 0.17"},
      {:httpoison, "~> 2.0"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
