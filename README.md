# logstash-json

Elixir Logger backend which sends logs to logstash in JSON format via TCP.

Also comes with a console logger.

## Configuration

In `mix.exs`, add `logstash_json` as a dependency and to your applications:

```
def application do
  [applications: [:logger, :logstash_json]]
end

defp deps do
  [{:logstash, github: "svetob/logstash-json"}]
end
```

In `config.exs` add the logger as a backend and configure it. For example:

```
config :logger,
  backends: [
    :console,
    {LogstashJson.TCP, :logstash}
  ]

config :logger, :logstash,
  level: :debug,
  host: System.get_env("LOGSTASH_TCP_HOST") || "localhost",
  port: System.get_env("LOGSTASH_TCP_PORT") || "4560",
  fields: %{appid: "schuppen"}
```

You can also log JSON to console if you'd like:

```
config :logger,
  backends: [
    {LogstashJson.TCP, :logstash},
    {LogstashJson.Console, :json}
  ]

config :logger, :logstash,
  level: :debug,
  host: System.get_env("LOGSTASH_TCP_HOST") || "docker.local",
  port: System.get_env("LOGSTASH_TCP_PORT") || "4560",
  fields: %{appid: "logstash-json"}

config :logger, :json,
  level: :debug
```

## TODO list

- UDP appender?
