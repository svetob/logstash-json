use Mix.Config

config :logger,
  backends: [
    {LogstashJson.Console, :json}
  ]

config :logger, :json,
  level: :info
