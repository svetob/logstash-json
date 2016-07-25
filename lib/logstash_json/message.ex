defmodule LogstashJson.Message do

  def message(level, msg, ts, md, %{metadata: metadata, fields: fields}) do
    json(level, msg, ts, md, %{metadata: metadata, fields: fields})
      |> Poison.encode!()
  end

  def json(level, msg, ts, md, %{metadata: metadata, fields: fields}) do
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
end
