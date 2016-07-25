# logstash-json

Elixir Logger backend for sending logs in JSON format to logstash via TCP.

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

In `config.exs` add the logger as a backend and configure it:

```
config :logger,
  backends: [:console, :logstash_json]

config :logger, :logstash_json,
  level: :debug,
  host: System.get_env("LOGSTASH_TCP_HOST") || "localhost",
  port: System.get_env("LOGSTASH_TCP_PORT") || "4560",
  fields: %{appid: "schuppen"}
```


## TODO list

- Handle connection problems (reconnects / logs when connection down)
- A test suite
- UDP appender?
- Console logger?
