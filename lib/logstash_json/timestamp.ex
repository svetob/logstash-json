defmodule LogstashJson.Timestamp do
  # Functions for generating timestamp
  def timestamp({{year, month, day}, {hour, min, sec, millis}}) do
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
end
