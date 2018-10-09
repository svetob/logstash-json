defmodule EventTest do
  use ExUnit.Case, async: false
  alias LogstashJson.Event

  defmodule Foo do
    defstruct [:bar]
  end

  test "Creates and serializes event" do
    message = "Meow meow"
    event = log(message)

    time = Map.get(event, :"@timestamp")

    assert Map.get(event, :message) == message
    assert Map.get(event, :level) == :info
    assert String.starts_with?(time, "2015-04-19T08:15:03.000")
    assert String.length(time) == 29
  end

  test "Joins extra fields but does not overwrite existing fields" do
    message = "Meow the second"
    event = log(message, %{foo: "bar", level: "fail", message: "fail"})

    assert Map.get(event, :message) == message
    assert Map.get(event, :level) == :info
    assert Map.get(event, :foo) == "bar"
  end

  test "Joins metadata fields but does not overwrite existing fields" do
    message = "Meow the second"
    event = log(message, %{}, [foo: "bar", level: "fail", message: "fail"])

    assert Map.get(event, :message) == message
    assert Map.get(event, :level) == :info
    assert Map.get(event, :foo) == "bar"
  end

  test "Adds no timezone offset for utc_log" do
    event = Event.event(:info, "", {{2015, 1, 1}, {0, 0, 0, 0}}, [], %{
      metadata: [],
      fields: %{},
      formatter: &(&1),
      utc_log: true
    })
    assert Map.get(event, :"@timestamp") =~ "+00:00"
  end

  test "Converts event to json" do
    message = "Meowson the third"
    event = message |> log_json() |> Poison.decode!()

    assert Map.get(event, "message") == message
    assert Map.get(event, "level") == "info"
  end

  test "Formats message" do
    message = ["Hello", 32, 'wo', ["rl", 'd!']]
      |> log()
      |> Map.get(:message)
    assert message == "Hello world!"
  end

  test "Handle lists such as [1, 2 | 3]" do
    message = ["a", "b" | "c"]
      |> log()
      |> Map.get(:message)
    assert message == "abc"
  end

  test "Includes metadata" do
    assert log("Hello", %{}, [foo: "Bar"])
      |> Map.get(:foo) == "Bar"
  end

  test "Serializes structs to maps" do
    event = log_json("Hello", %{}, [foo: %Foo{bar: "baz"}]) |> Poison.decode!()
    assert %{"message" => "Hello", "foo" => %{"bar" => "baz"}} = event
  end

  test "Serializes tuples to lists" do
    event = log_json("Hello", %{}, [foo: {:bar, :baz}]) |> Poison.decode!()
    assert %{"message" => "Hello", "foo" => ["bar", "baz"]} = event
  end

  test "Inspect non-string binaries" do
    binary = <<171, 152, 70, 16, 37>>
    assert String.valid?(binary) == false

    binary_inspected = inspect(binary)
    event = binary |> log_json(%{foo: binary}, bar: binary) |> Poison.decode!()

    assert event["message"] == binary_inspected
    assert event["bar"] == binary_inspected
    assert event["foo"] == binary_inspected
  end

  test "Formatter is used" do
    assert log("Something", %{}, [], &(Map.put(&1, :hello, "there")))
    |> Map.get(:hello) == "there"
  end

  defp log(msg, fields \\ %{}, metadata \\ [], formatter \\ &(&1)) do
    Event.event(:info, msg, {{2015, 4, 19}, {8, 15, 3, 28}}, metadata, %{
      fields: fields,
      formatter: formatter,
      utc_log: false
    })
  end

  defp log_json(msg, fields \\ %{}, metadata \\ []) do
    {:ok, l} = Event.json(log(msg, fields, metadata))
    l
  end
end
