defmodule LogstashJson.Timestamp do
  # Functions for generating timestamp
  def timestamp({{year, month, day}, {hour, min, sec, millis}}) do
    pad(year,4) <> "-" <> pad(month, 2) <> "-" <> pad(day,2) <> "T" <>
      pad(hour, 2) <> ":" <> pad(min, 2) <> ":" <> pad(sec, 2) <> "." <> pad(millis, 3) <>
      timezone()
  end

  # This is the part where we need a large dependency just for local timezone
  defp timezone() do
    local = Timex.Timezone.local()
    offset = local.offset_utc + local.offset_std
    minute = abs(offset) |> rem(3600) |> div(60)
    hour   = abs(offset) |> div(3600)
    sign(offset) <> pad(hour, 2) <> ":" <> pad(minute, 2)
  end

  defp sign(total) when total < 0, do: "-"
  defp sign(_),                    do: "+"

  defp pad(val, count) do
    num = Integer.to_string(val)
    :binary.copy("0", count - byte_size(num)) <> num
  end
end
