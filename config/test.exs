use Mix.Config

config :logger,
  backends: [
    {LogstashJson.Console, :json}
  ]

config :logger, :json,
  level: :info

config :logger, :logstash,
  level: :debug,
  host: "localhost",
  fields: %{appid: "logstash-json"},
  workers: 1,
  buffer_size: 10_000

config :logger, :logstash_with_formatter,
  level: :debug,
  host: "localhost",
  fields: %{appid: "logstash-json"},
  workers: 1,
  buffer_size: 10_000,
  formatter: fn (event) -> event |> Map.put(:added_by_formatter, "I am extra") end
