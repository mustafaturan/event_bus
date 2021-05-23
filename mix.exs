defmodule EventBus.Mixfile do
  use Mix.Project

  @source_url "https://github.com/mustafaturan/event_bus"
  @version "1.6.2"

  def project do
    [
      app: :event_bus,
      version: @version,
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      docs: docs(),
      dialyzer: [plt_add_deps: :transitive],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [
      extra_applications: [:logger, :crypto],
      mod: {EventBus.Application, []}
    ]
  end

  defp elixirc_paths(:test) do
    ["lib", "test/support"]
  end

  defp elixirc_paths(_) do
    ["lib"]
  end

  defp deps do
    [
      {:credo, "~> 1.5", only: [:dev, :test]},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.13", only: [:test]},
      {:ex_doc, ">= 0.0.0", only: [:dev], runtime: false}
    ]
  end

  defp description do
    """
    Traceable, extendable and minimalist event bus implementation for Elixir
    with built-in event store and event watcher based on ETS
    """
  end

  defp package do
    [
      name: :event_bus,
      description: description(),
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md", "LICENSE.md"],
      maintainers: ["Mustafa Turan"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "https://hexdocs.pm/event_bus/changelog.html",
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md": [title: "Changelog"],
        "CONTRIBUTING.md": [title: "Contributing"],
        "CODE_OF_CONDUCT.md": [title: "Code of Conduct"],
        "LICENSE.md": [title: "License"],
        "QUESTIONS.md": [title: "Questions"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
