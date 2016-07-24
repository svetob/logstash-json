defmodule Logger.Backends.Logstash do
  use GenEvent

  # TODO Add reconnect logic
  # TODO What to do on log if connection is down?

  def init(_) do
    {:ok, configure([])}
  end

  def handle_call({:configure, opts}, _state) do
    {:ok, :ok, configure(opts)}
  end

  def handle_event(:flush, state) do
    {:ok, state}
  end

  def handle_event({_level, gl, {Logger, _, _, _}}, state) when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, %{level: min_level} = state) do
    if is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt do
      log_event(level, msg, ts, md, state)
    end
    {:ok, state}
  end

  def terminate(_reason, %{socket: socket}) do
    :gen_tcp.close socket
    :ok
  end

  ## Helpers
  @timeout 10000
  defp configure(opts) do
    env = Application.get_env(:logger, :logstash_json, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, :logstash_json, opts)

    level    = Keyword.get(opts, :level)
    host     = Keyword.get(opts, :host)
    port     = Keyword.get(opts, :port)
    metadata = Keyword.get(opts, :metadata)
    fields   = Keyword.get(opts, :fields) || %{}

    socket = connect(host, port)

    %{metadata: metadata, level: level, host: host, port: port, socket: socket, fields: fields}
  end

  @connection_opts [:binary, {:packet, 0}, {:nodelay, true}, {:keepalive, true}]

  defp connect(host, port) do
    case :gen_tcp.connect(host, port, [:binary, active: :once]) do
      {:ok, socket} ->
        socket
      {:error, _} ->
        # TODO Handle error
        nil
    end
  end

  defp log_event(_level, _msg, _ts, _md, %{socket: nil} = state) do
    {:noreply, state}
  end

  defp log_event(level, msg, ts, md, %{socket: socket} = state) do
    log = log_json(level, msg, ts, md, state) <> "\n"
    case :gen_tcp.send(socket, log) do
      :ok ->
        {:noreply, state}
      {:error, _reason} ->
        # TODO
        {:noreply, state}
    end
  end

  defp log_json(level, msg, ts, md, %{metadata: metadata, fields: fields}) do
    %{
      "@timestamp": LogstashJson.Timestamp.timestamp(ts),
      level: level,
      message: msg,
      metadata: metadata,
      module: md[:module],
      function: md[:function],
      line: md[:line]
    } |> Map.merge(fields) |> Poison.encode!()
  end
end
