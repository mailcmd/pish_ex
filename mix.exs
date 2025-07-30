defmodule PishEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :pish_ex,
      description: "Module that allow to run interactive shell processes and interact with them mimicking a human input/output interaction",
      version: "0.2.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      package: package(),
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
      {:porcelain, "~> 2.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true}
    ]
  end

  defp package() do
    [
      name: "pish_ex",
      description: "Module that allow to run interactive shell processes and interact with them mimicking a human input/output interaction",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/mailcmd/pish_ex"},
      source_url: "https://github.com/mailcmd/pish_ex",
    ]
  end

end
