defmodule LogstashJson.Event do

  @moduledoc """
  This module contains functions for generating and serializing logs events.
  """

  @doc "Generate a log event from log data"
  def event(level, msg, ts, md, %{fields: fields, utc_log: utc_log}) do
    fields
    |> format_fields(%{
        "@timestamp": timestamp(ts, utc_log),
        level: level,
        message: to_string(msg),
        metadata: format_metadata(md),
        module: md[:module],
        function: md[:function],
        line: md[:line]
      }
    )
  end

  @doc "Serialize a log event to a JSON string"
  def json(event) do
    event |> print_pids |> Poison.encode()
  end

  def format_fields(fields, field_overrides) do
    fields
    |> Map.merge(field_overrides)
    |> include_in_parent(field_overrides[:metadata])
  end

  defp format_metadata(metadata) do
    metadata
    |> Enum.into(%{})
  end

  defp include_in_parent(fields, nil), do: fields
  defp include_in_parent(fields, metadata) do
    fields
    |> Map.merge(Map.drop(metadata, Map.keys(fields)))
  end

  # Functions for generating timestamp
  defp timestamp(ts, utc_log) do
    datetime(ts) <> timezone(utc_log)
  end

  defp datetime({{year, month, day}, {hour, min, sec, millis}}) do
    pad(year, 4) <> "-" <> pad(month, 2) <> "-" <> pad(day, 2) <> "T" <>
      pad(hour, 2) <> ":" <> pad(min, 2) <> ":" <> pad(sec, 2) <> "." <> pad(millis, 3)
  end

  defp timezone(_utc_true = true), do: "+00:00"
  defp timezone(_), do: timezone()

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
  defp print_pids(it) when is_tuple(it), do: print_pids(Tuple.to_list(it))
  defp print_pids(%_{} = it),            do: print_pids(Map.from_struct(it))
  defp print_pids(it) when is_map(it),   do: Enum.into(it, %{}, fn {k, v} -> {k, print_pids(v)} end)
  defp print_pids(it), do: it
end
