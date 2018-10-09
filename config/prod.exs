use Mix.Config

config :logger,
  backends: [
    {LogstashJson.TCP, :logstash},
    {LogstashJson.Console, :json}
  ]

config :logger, :logstash,
  level: :debug,
  host: System.get_env("LOGSTASH_TCP_HOST") || "localhost",
  port: System.get_env("LOGSTASH_TCP_PORT") || "4560",
  fields: %{appid: "logstash-json"},
  workers: 2,
  buffer_size: 10_000

config :logger, :json, level: :info
