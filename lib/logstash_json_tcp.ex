defmodule LogstashJson.TCP do
  @moduledoc """
  Logger backend which sends logs to logstash via TCP in JSON format.
  """

  @behaviour :gen_event

  import Supervisor.Spec
  alias LogstashJson.TCP

  @doc false
  def init({__MODULE__, name}) do
    if user = Process.whereis(:user) do
      Process.group_leader(self(), user)
      {:ok, configure(name, [])}
    else
      {:error, :ignore}
    end
  end

  @doc false
  def handle_call({:configure, opts}, %{name: name}) do
    {:ok, :ok, configure(name, opts)}
  end

  @doc false
  def handle_info(_msg, state) do
    {:ok, state}
  end

  @doc false
  def handle_event(:flush, state) do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, %{level: min_level} = state) do
    if is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt do
      log_event(level, msg, ts, md, state)
    end

    {:ok, state}
  end

  @doc false
  def terminate(_reason, _state) do
    :ok
  end

  @doc false
  def code_change(_old, state, _extra) do
    {:ok, state}
  end

  defp log_event(level, msg, ts, md, state) do
    event = LogstashJson.Event.event(level, msg, ts, md, state)

    case LogstashJson.Event.json(event) do
      {:ok, log} ->
        send_log(log, state)

      {:error, reason} ->
        IO.puts("Failed to serialize event. error: #{inspect(reason)}, event: #{inspect(event)}")
    end
  end

  defp send_log(log, %{queue: queue}) do
    BlockingQueue.push(queue, log <> "\n")
  end

  defp configure(name, opts) do
    env = Application.get_env(:logger, name, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, name, opts)

    level = Keyword.get(opts, :level) || :debug
    host = opts |> Keyword.get(:host) |> env_var |> to_charlist
    port = opts |> Keyword.get(:port) |> env_var |> to_int
    fields = Keyword.get(opts, :fields) || %{}
    workers = Keyword.get(opts, :workers) || 2
    worker_pool = Keyword.get(opts, :worker_pool) || nil
    buffer_size = Keyword.get(opts, :buffer_size) || 10_000
    utc_log = Application.get_env(:logger, :utc_log, false)

    formatter =
      case LogstashJson.Event.resolve_formatter_config(Keyword.get(opts, :formatter)) do
        {:ok, fun} ->
          fun

        {:error, bad_formatter} ->
          raise "Bad formatter configured for :logger, #{name} -- #{inspect(bad_formatter)}"
      end

    # Close previous worker pool
    if worker_pool != nil do
      :ok = Supervisor.stop(worker_pool)
    end

    # Create new queue and worker pool
    {:ok, queue} = BlockingQueue.start_link(buffer_size)

    children = 1..workers |> Enum.map(&tcp_worker(&1, host, port, queue))
    {:ok, worker_pool} = Supervisor.start_link(children, strategy: :one_for_one)

    %{
      level: level,
      host: host,
      port: port,
      fields: fields,
      name: name,
      queue: queue,
      worker_pool: worker_pool,
      formatter: formatter,
      utc_log: utc_log
    }
  end

  defp env_var({:system, var, default}), do: System.get_env(var) || default
  defp env_var({:system, var}), do: System.get_env(var)
  defp env_var(value), do: value

  defp to_int(val) when is_integer(val), do: val
  defp to_int(val), do: val |> Integer.parse() |> elem(0)

  defp tcp_worker(id, host, port, queue) do
    worker(TCP.Connection, [host, port, queue, id], id: id)
  end
end
