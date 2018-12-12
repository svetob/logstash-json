# logstash-json ![](https://travis-ci.org/svetob/logstash-json.svg?branch=master)

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
  formatter: {MyApp, :formatter},
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
- __formatter__: Function to format TCP output. Can be either a function or a reference to a function in the form `{MyModule, :my_functiotn_name}` The function itself takes a Map and returns a possibly altered Map. (Default: `&(&1)`)

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
Using `Logger.metadata/1` it is possible to send additional information that can be sent as a part of a log statement. These will appear in Kibana as top level fields and also collected in a separate field. An example is to send HTTP status codes or request duration details.
Metadata can also be appended with the second argument of `Logger.info/2`.

```Elixir
iex(1)> require Logger
Logger
iex(2)> Logger.metadata([status: 200, method: "GET"])
:ok
iex(3)> Logger.info "Test"
:ok
{"status":200,"pid":"#PID<0.160.0>","module":null,"method":"GET","metadata":{"status":200,"pid":"#PID<0.160.0>","module":null,"method":"GET","line":3,"function":null,"file":"iex"},"message":"Test","line":3,"level":"info","function":null,"file":"iex","@timestamp":"2017-08-09T15:48:13.941+02:00"}
iex(4)> Logger.info "Test", [foo: "bar"]
{"status":200,"pid":"#PID<0.160.0>","module":null,"method":"GET","metadata":{"status":200,"pid":"#PID<0.160.0>","module":null,"method":"GET","line":5,"function":null,"foo":"bar","file":"iex"},"message":"Test","line":5,"level":"info","function":null,"foo":"bar","file":"iex","@timestamp":"2017-08-09T15:48:36.910+02:00"}
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

#### Using a Formatter
Using the example TCP logger backend configuration above (minus the :console backend) with the following code:

```Elixir
defmodule MyApp do
  require Logger

  def level_name_to_syslog_level(level_name, default_level \\ 6) do
     case level_name do
        :error -> 3
        :warn -> 4
        :info -> 6
        :debug -> 7
        level when is_integer(level) -> level
        _ -> default_level
     end
  end

  def formatter(event) do
    event
    |> Map.put(:level, level_name_to_syslog_level(event[:level]))
    |> Map.put(:beam_pid, event[:pid])
    |> Map.delete(:pid)
    |> Map.delete(:file)
    |> Map.delete(:line)
  end

  def try_to_log(message) do
    Logger.info(message)
  end
end
```

```Elixir
iex(1)> require Logger
Logger
iex(2)> Logger.error("an error")
:ok
iex(3)> MyApp.try_to_log("hello there")
:ok
iex(4)>
```

Results in the following being sent via TCP:
```JSON
{"module":null,"message":"an error","level":3,"function":null,"beam_pid":"#PID<0.206.0>","appid":"my-app","@timestamp":"2017-12-29T19:16:29.397+00:00"}
{"module":"Elixir.MyApp","message":"hello there","level":6,"function":"try_to_log/1","beam_pid":"#PID<0.206.0>","application":"thing","appid":"my-app","@timestamp":"2017-12-29T19:16:42.434+00:00"}
```
