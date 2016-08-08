defmodule LogstashJson.TCP do
  use GenEvent
  alias LogstashJson.TCP

  def init({__MODULE__, name}) do
    if user = Process.whereis(:user) do
      Process.group_leader(self(), user)
      {:ok, configure(name, [])}
    else
      {:error, :ignore}
    end
  end

  def handle_call({:configure, opts}, %{name: name}) do
    {:ok, :ok, configure(name, opts)}
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

  def terminate(_reason, %{conn: conn}) do
    TCP.Connection.close conn
    :ok
  end

  defp configure(name, opts) do
    env = Application.get_env(:logger, name, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, name, opts)

    level      = Keyword.get(opts, :level) || :debug
    host       = opts |> Keyword.get(:host) |> env_var |> to_char_list
    port       = opts |> Keyword.get(:port) |> env_var |> to_int
    metadata   = Keyword.get(opts, :metadata) || []
    fields     = Keyword.get(opts, :fields) || %{}

    {:ok, conn} = connect(host, port)

    %{metadata: metadata,
      level: level,
      host: host,
      port: port,
      conn: conn,
      fields: fields,
      name: name}
  end

  defp env_var({:system, var, default}) do
    case System.get_env(var) do
      nil -> default
      value -> value
    end
  end
  defp env_var({:system, var}) do
    System.get_env(var)
  end
  defp env_var(value) do
    value
  end

  defp to_int(val) when is_integer(val) do
    val
  end
  defp to_int(val) do
    val
    |> Integer.parse
    |> elem(0)
  end

  @connection_opts [mode: :binary, keepalive: true]
  defp connect(host, port) do
    TCP.Connection.start_link(host, port, @connection_opts)
  end

  defp log_event(level, msg, ts, md, %{conn: conn} = state) do
    log = LogstashJson.Message.message(level, msg, ts, md, state) <> "\n"
    case TCP.Connection.send(conn, log) do
      :ok ->
        {:noreply, state}
      {:error, reason} ->
        IO.puts "#{__MODULE__}: Error when logging: #{inspect reason}"
        {:noreply, state}
    end
  end
end
