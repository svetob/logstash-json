defmodule LogstashJson.Event do

  @moduledoc """
  This module contains functions for generating and serializing logs events.
  """

  @doc "Generate a log event from log data"
  def event(level, msg, ts, md, %{metadata: metadata, fields: fields}) do
    Map.merge(fields, %{
      "@timestamp": timestamp(ts),
      level: level,
      message: to_string(msg),
      metadata: metadata,
      module: md[:module],
      function: md[:function],
      line: md[:line]
    })
  end

  @doc "Serialize a log event to a JSON string"
  def json(event) do
    event |> print_pids |> Poison.encode()
  end


  # Functions for generating timestamp
  defp timestamp({{year, month, day}, {hour, min, sec, millis}}) do
    pad(year,4) <> "-" <> pad(month, 2) <> "-" <> pad(day,2) <> "T" <>
      pad(hour, 2) <> ":" <> pad(min, 2) <> ":" <> pad(sec, 2) <> "." <> pad(millis, 3) <>
      timezone()
  end

  defp timezone() do
    offset = timezone_offset()
    minute = offset |> abs() |> rem(3600) |> div(60)
    hour   = offset |> abs() |> div(3600)
    sign(offset) <> pad(hour, 2) <> ":" <> pad(minute, 2)
  end

  defp timezone_offset() do
    t_utc = :calendar.universal_time()
    t_local = :calendar.universal_time_to_local_time(t_utc)

    s_utc = :calendar.datetime_to_gregorian_seconds(t_utc)
    s_local = :calendar.datetime_to_gregorian_seconds(t_local)

    s_local - s_utc
  end

  defp sign(total) when total < 0, do: "-"
  defp sign(_),                    do: "+"

  defp pad(val, count) do
    num = Integer.to_string(val)
    :binary.copy("0", count - byte_size(num)) <> num
  end

  # Traverse complex objects and inspect PID's to their string representation
  defp print_pids(it) when is_pid(it),   do: inspect(it)
  defp print_pids(it) when is_list(it),  do: Enum.map it, &print_pids/1
  defp print_pids(it) when is_tuple(it), do: List.to_tuple(print_pids(Tuple.to_list(it)))
  defp print_pids(it) when is_map(it),   do: Enum.into(it, %{}, fn {k, v} -> {k, print_pids(v)} end)
  defp print_pids(it), do: it
end
