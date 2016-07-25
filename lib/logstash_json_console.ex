defmodule LogstashJson.Console do
  use GenEvent

  def init({__MODULE__, name}) do
    {:ok, configure(name, [])}
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

  def terminate(_reason, _state) do
    :ok
  end

  ## Helpers
  defp configure(name, opts) do
    env = Application.get_env(:logger, name, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, name, opts)

    level    = Keyword.get(opts, :level)
    metadata = Keyword.get(opts, :metadata)
    fields   = Keyword.get(opts, :fields) || %{}

    %{metadata: metadata, level: level, fields: fields}
  end

  defp log_event(level, msg, ts, md, state) do
    IO.puts LogstashJson.Message.message(level, msg, ts, md, state)
  end
end
