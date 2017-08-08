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

```Elixir
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

```Elixir
config :logger,
  backends: [
    {LogstashJson.Console, :json}
  ]

config :logger, :json,
  level: :debug
```

#### Passing additional Metadata
Using `Logger.metadata/1` it is possible to send additional information that can be sent as a part of a log statement. These will appear in Kibana as separate fields. An example is to send HTTP status codes or request duration details.
Metadata can also be appended with the second argument of `Logger.info/2`.

```Elixir
iex(1)> require Logger
Logger
iex(2)> Logger.metadata([status: 200, method: "GET"])
:ok
iex(3)> Logger.info "Test"
:ok
{"module":null,"metadata":{"status":200,"pid":"#PID<0.157.0>","module":null,"method":"GET","line":3,"function":null,"file":"iex"},"message":"Test","line":3,"level":"info","function":null,"@timestamp":"2017-05-15T16:12:26.568+02:00"}
iex(4)> Logger.info "Test", [foo: "bar"]
{"module":null,"metadata":{"status":200,"pid":"#PID<0.157.0>","module":null,"method":"GET","line":4,"function":null,"foo":"bar","file":"iex"},"message":"Test","line":4,"level":"info","function":null,"@timestamp":"2017-05-15T16:13:18.254+02:00"}
```

By adding a special key, `include_in_parent`, it is possible to add additional fields to the JSON payload. This will not override fields already there.

```Elixir
iex(1)> require Logger
Logger
iex(2)> Logger.metadata([include_in_parent: %{add_this: "to_parent"}])
:ok
iex(3)> Logger.info "Test"
:ok
{"module":null,"metadata":{"pid":"#PID<0.149.0>","module":null,"line":3,"function":null,"file":"iex"},"message":"Test","line":3,"level":"info","function":null,"add_this":"to_parent","@timestamp":"2017-08-08T12:22:12.664+02:00"}
iex(4)> Logger.info "Test", [include_in_parent: %{foo: "bar"}]
{"module":null,"metadata":{"pid":"#PID<0.149.0>","module":null,"line":5,"function":null,"file":"iex"},"message":"Test","line":5,"level":"info","function":null,"foo":"bar","@timestamp":"2017-08-08T12:22:54.789+02:00"}
```
 
Here is an example plug for setting the Metadata

```Elixir
defmodule LoggerMetadata do
  @behaviour Plug
  require Logger

  def init(opts) do
    Keyword.get(opts, :log, :info)
  end

  def call(conn, level) do
    Plug.Conn.register_before_send(conn, fn(conn) ->
      status = conn.status
      Logger.metadata([
        status: status,
        request_path: conn.request_path,
        method: conn.method,
        query_string: conn.query_string
      ])

      Logger.log(level, fn ->
        metadata = Logger.metadata
        duration = Keyword.get(metadata, :duration, -1)
        "#{conn.method} #{conn.request_path} :: #{status} in #{duration}ms"
      end)

      conn
    end)
  end
end
```



## TODO list

- UDP appender?
