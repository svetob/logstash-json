defmodule EventTest do
  use ExUnit.Case
  alias LogstashJson.Event

  test "Creates and serializes event" do
    message = "Meow meow"
    event = log(message)

    time = Map.get(event, :"@timestamp")

    assert Map.get(event, :message) == message
    assert Map.get(event, :level) == :info
    assert Map.get(event, :metadata) == []
    assert String.length(time) == 29
  end

  test "Joins extra fields but does not overwrite existing fields" do
    message = "Meow the second"
    event = log(message, %{foo: "bar", level: "fail", message: "fail"})

    assert Map.get(event, :message) == message
    assert Map.get(event, :level) == :info
    assert Map.get(event, :foo) == "bar"
  end

  test "Converts event to json" do
    message = "Meowson the third"
    event = log_json(message) |> Poison.decode!()

    assert Map.get(event, "message") == message
    assert Map.get(event, "level") == "info"
  end

  test "Formats message" do
    assert log(["Hello", 32, 'wo', ["rl", 'd!']])
      |> Map.get(:message) == "Hello world!"
  end

  test "Handle lists such as [1, 2 | 3]" do
    assert log(["a", "b" | "c"])
      |> Map.get(:message) == "abc"
  end

  defp log(msg, fields \\ %{}) do
    Event.event(:info, msg, {{2015,1,1},{0,0,0,0}}, [], %{
      metadata: [],
      fields: fields
    })
  end

  defp log_json(msg, fields \\ %{}) do
    {:ok, l} = Event.json(log(msg, fields))
    l
  end
end
