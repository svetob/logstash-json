defmodule LogstashJson.Event do
  @moduledoc """
  This module contains functions for generating and serializing logs events.
  """

  @doc "Generate a log event from log data"
  def event(level, msg, ts, md, %{fields: fields, utc_log: utc_log, formatter: formatter}) do
    fields
    |> format_fields(md, %{
      "@timestamp": timestamp(ts, utc_log),
      level: level,
      message: to_string(msg),
      module: md[:module],
      function: md[:function],
      line: md[:line]
    })
    |> formatter.()
  end

  @doc "Serialize a log event to a JSON string"
  def json(event) do
    event |> print_pids |> Poison.encode()
  end

  def format_fields(fields, metadata, field_overrides) do
    metadata
    |> format_metadata()
    |> Map.merge(fields)
    |> Map.merge(field_overrides)
  end

  defp format_metadata(metadata) do
    metadata
    |> Enum.into(%{})
  end

  def resolve_formatter_config(formatter_spec, default_formatter \\ & &1) do
    # Find an appropriate formatter, if possible, from this config spec.
    case formatter_spec do
      {module, function} ->
        if Keyword.has_key?(module.__info__(:functions), function) do
          {:ok, &apply(module, function, [&1])}
        else
          {:error, {module, function}}
        end

      fun when is_function(fun) ->
        {:ok, fun}

      nil ->
        {:ok, default_formatter}

      bad_formatter ->
        {:error, bad_formatter}
    end
  end

  # Functions for generating timestamp
  defp timestamp(ts, utc_log) do
    datetime(ts) <> timezone(utc_log)
  end

  defp datetime({{year, month, day}, {hour, min, sec, millis}}) do
    {:ok, ndt} = NaiveDateTime.new(year, month, day, hour, min, sec, {millis * 1000, 3})
    NaiveDateTime.to_iso8601(ndt)
  end

  defp timezone(true), do: "+00:00"
  defp timezone(_), do: timezone()

  defp timezone() do
    offset = timezone_offset()
    minute = offset |> abs() |> rem(3600) |> div(60)
    hour = offset |> abs() |> div(3600)
    sign(offset) <> zero_pad(hour, 2) <> ":" <> zero_pad(minute, 2)
  end

  defp timezone_offset() do
    t_utc = :calendar.universal_time()
    t_local = :calendar.universal_time_to_local_time(t_utc)

    s_utc = :calendar.datetime_to_gregorian_seconds(t_utc)
    s_local = :calendar.datetime_to_gregorian_seconds(t_local)

    s_local - s_utc
  end

  defp sign(total) when total < 0, do: "-"
  defp sign(_), do: "+"

  defp zero_pad(val, count) do
    num = Integer.to_string(val)
    :binary.copy("0", count - byte_size(num)) <> num
  end

  # Traverse complex objects and inspect PID's to their string representation
  defp print_pids(it) when is_pid(it), do: inspect(it)
  defp print_pids(it) when is_list(it), do: Enum.map(it, &print_pids/1)
  defp print_pids(it) when is_tuple(it), do: print_pids(Tuple.to_list(it))
  defp print_pids(%_{} = it), do: print_pids(Map.from_struct(it))

  defp print_pids(it) when is_map(it),
    do: Enum.into(it, %{}, fn {k, v} -> {print_pids(k), print_pids(v)} end)

  defp print_pids(it) when is_binary(it) do
    it
    |> String.valid?()
    |> case do
      true -> it
      false -> inspect(it)
    end
  end

  defp print_pids(it), do: it
end
