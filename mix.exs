defmodule LogstashJson.Mixfile do
  use Mix.Project

  @source_url "https://github.com/svetob/logstash-json"
  @version "0.7.5"

  def project do
    [
      app: :logstash_json,
      version: @version,
      elixir: "~> 1.4",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      docs: docs(),
      package: package(),
      preferred_cli_env: [docs: :docs]
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:connection, "~> 1.0"},
      {:jason, "~> 1.2", optional: true},
      {:blocking_queue, "~> 1.3", optional: true},
      {:ex_doc, ">= 0.0.0", only: :docs, runtime: false},
      {:credo, ">= 0.0.0", only: :dev}
    ]
  end

  defp package do
    [
      name: :logstash_json,
      description: "Formats logs as JSON, forwards to Logstash via TCP, or to console.",
      maintainers: ["Tobias Ara Svensson"],
      licenses: ["MIT"],
      links: %{"Github" => @source_url}
    ]
  end

  defp docs do
    [
      extras: [
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
