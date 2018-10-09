defmodule LogstashJson.Mixfile do
  use Mix.Project

  def project do
    [
      app: :logstash_json,
      version: "0.7.2",
      elixir: "~> 1.4",
      description: description(),
      package: package(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [applications: [:logger, :poison, :blocking_queue]]
  end

  defp deps do
    [
      {:connection, "~> 1.0.4"},
      {:poison, ">= 1.0.0"},
      {:blocking_queue, "~> 1.3.0"},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:credo, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    Formats logs as JSON, forwards to Logstash via TCP, or to console.
    """
  end

  defp package do
    [
      name: :logstash_json,
      maintainers: ["Tobias Ara Svensson"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/svetob/logstash-json"}
    ]
  end
end
