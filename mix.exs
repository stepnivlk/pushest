defmodule Pushest.MixProject do
  use Mix.Project

  def project do
    [
      app: :pushest,
      version: "0.2.1",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Pushest",
      description: description(),
      package: package(),
      source_url: "https://github.com/stepnivlk/pushest",
      homepage_url: "https://github.com/stepnivlk/pushest",
      docs: [main: "Pushest", extras: ["README.md"]]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :gun]
    ]
  end

  defp deps do
    [
      {:poison, "~> 3.1"},
      {:gun, "1.0.0-pre.5"},
      {:credo, "~> 0.9.0-rc1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.18.3", only: [:dev], runtime: false}
    ]
  end

  defp description() do
    "Bidirectional Pusher client in Elixir."
  end

  defp package() do
    [
      maintainers: ["Tomas Koutsky"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/stepnivlk/pushest"}
    ]
  end
end
