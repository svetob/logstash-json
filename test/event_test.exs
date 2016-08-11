defmodule EventTest do
  use ExUnit.Case
  alias LogstashJson.Event

  test "Creates and serializes event" do
    message = "Meow meow"
    event = log(message)
      |> Poison.decode!()

    assert Map.get(event, "message") == message
    assert Map.get(event, "level") == "info"
    assert Map.get(event, "metadata") == []
    assert String.length(Map.get(event, "@timestamp")) == 29
  end

  test "Joins extra fields but does not overwrite existing fields" do
    message = "Meow the second"
    event = log(message, %{foo: "bar", level: "fail", message: "fail"})
      |> Poison.decode!()

    assert Map.get(event, "message") == message
    assert Map.get(event, "level") == "info"
    assert Map.get(event, "foo") == "bar"
  end

  test "Handle construct [1, 2 | 3]" do
    assert log(["a", "b" | "c"])
      |> Poison.decode!()
      |> Map.get("message") == ["a", "b", "c"]
  end

  defp log(msg) do
    log(msg, %{})
  end
  defp log(msg, fields) do
    {:ok, l} = Event.event(:info, msg, {{2015,1,1},{0,0,0,0}}, [], %{
      metadata: [],
      fields: fields
      }) |> Event.json()
    l
  end
end
