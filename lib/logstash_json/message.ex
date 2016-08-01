defmodule LogstashJson.Message do

  def message(level, msg, ts, md, %{metadata: metadata, fields: fields}) do
    json(level, msg, ts, md, metadata |> print_pids, fields |> print_pids)
      |> Poison.encode!()
  end

  defp json(level, msg, ts, md, metadata, fields) do
    %{
      "@timestamp": LogstashJson.Timestamp.timestamp(ts),
      level: level,
      message: msg,
      metadata: metadata,
      module: md[:module],
      function: md[:function],
      line: md[:line]
    } |> Map.merge(fields)
  end

  defp print_pids(it) when is_map(it), do: Enum.into it, %{}, fn {k, v} -> {k, print_pids(v)} end
  defp print_pids(it) when is_list(it), do: Enum.map it, fn x -> print_pids(x) end
  defp print_pids(it) when is_tuple(it), do: List.to_tuple(print_pids(Tuple.to_list(it)))
  defp print_pids(it) when is_pid(it), do: inspect(it)
  defp print_pids(it), do: it
end
