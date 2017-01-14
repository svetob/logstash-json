defmodule LogstashJson.Mixfile do
  use Mix.Project

  def project do
    [app: :logstash_json,
     version: "0.4.0",
     elixir: "~> 1.3",
     description: description(),
     package: package(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:connection, "~> 1.0.3"},
     {:poison, "~> 2.1"},
     {:blocking_queue, "~> 1.0"},
     {:ex_doc, ">= 0.0.0", only: :dev}]
  end

  defp description do
    """
    Elixir Logger backend which sends logs to logstash in JSON format via TCP.
    """
  end

  defp package do
    [ name: :logstash_json,
      maintainers: ["Tobias Ara Svensson"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/svetob/logstash-json"},
    ]
  end
end
