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

### Logstash TCP logger backend
In `config.exs` add the TCP logger as a backend and configure it:

```
config :logger,
  backends: [
    :console,
    {LogstashJson.TCP, :logstash}
  ]

config :logger, :logstash,
  level: :debug,
  fields: %{appid: "my-app"},
  host: {:system, "LOGSTASH_TCP_HOST", "localhost"},
  port: {:system, "LOGSTASH_TCP_PORT", "4560"},
  workers: 2,
  buffer_size: 10_000
```

The parameters are:
- __host__: (Required) Logstash host.
- __port__: (Required) Logstash port.
- __workers__: Number of TCP workers, each worker opens a new TCP connection. (Default: 2)
- __buffer_size__: Size of internal message buffer, used when logs are generated faster than logstash can consume them. (Default: 10_000)
- __fields__: Additional fields to add to the JSON payload, such as appid. (Default: none)

The TCP logger handles various failure scenarios differently:
- If the internal message buffer fills up, logging new messages __blocks__ until more messages are sent and there is space available in the buffer again.
- If the logstash connection is lost, logged messages are __dropped__.

### Console logger backend

You can also log JSON to console if you'd like:

```
config :logger,
  backends: [
    {LogstashJson.Console, :json}
  ]

config :logger, :json,
  level: :debug
```

## TODO list

- UDP appender?
