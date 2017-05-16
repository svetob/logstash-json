defmodule LogstashJsonConsoleTest do
  use ExUnit.Case, async: false
  require Logger

  import ExUnit.CaptureIO

  @moduledoc """
  Unit tests for console logger output.
  """

  test "Happy case" do
    io = capture_io(fn ->
      logger = new_logger()
      log(logger, "Hello world!")
      GenEvent.stop(logger)
    end)

    event = Poison.decode!(io)
    assert event["message"] == "Hello world!"
    assert event["level"] == "info"
  end

  test "Log messages end with newline" do
    io = capture_io(fn ->
      logger = new_logger()
      log(logger, "Hello world!")
      GenEvent.stop(logger)
    end)

    assert io |> String.ends_with?("\n")
  end

  test "Logs with correct log level" do
    io = capture_io(fn ->
      logger = new_logger()
      log(logger, "Hello world!", :warn)
      GenEvent.stop(logger)
    end)

    event = Poison.decode!(io)
    assert event["level"] == "warn"
  end

  test "Can print several messages" do
    io = capture_io(fn ->
      logger = new_logger()
      log(logger, "Hello world!")
      log(logger, "Foo?")
      log(logger, "Bar!")
      GenEvent.stop(logger)
    end)

    lines = io |> String.trim() |> String.split("\n") |> List.to_tuple()
    assert tuple_size(lines) == 3
    assert lines |> elem(0) |> Poison.decode! |> Map.get("message") == "Hello world!"
    assert lines |> elem(1) |> Poison.decode! |> Map.get("message") == "Foo?"
    assert lines |> elem(2) |> Poison.decode! |> Map.get("message") == "Bar!"
  end

  test "Sent messages include metadata" do
    io = capture_io(fn ->
      logger = new_logger()
      log(logger, "Hello world!", :info, [car: "Lamborghini"])
      GenEvent.stop(logger)
    end)

    event = Poison.decode!(io)
    assert event["metadata"]["car"]  == "Lamborghini"

  end

  test "Sent messages include static fields" do
    opts = :logger |> Application.get_env(:json) |> Keyword.put(:fields, %{test_field: "test_value"})
    Application.put_env(:logger, :json, opts)

    io = capture_io(fn ->
      logger = new_logger()
      log(logger, "Hello world!")
      GenEvent.stop(logger)
    end)

    event = Poison.decode!(io)
    assert event["test_field"] == "test_value"
  end

  defp new_logger do
    {:ok, manager} = GenEvent.start_link()
    GenEvent.add_handler(manager, LogstashJson.Console, {LogstashJson.Console, :json})
    manager
  end

  defp log(logger, msg, level \\ :info, metadata \\ []) do
    ts = {{2017, 1, 1}, {1, 2, 3, 400}}
    GenEvent.notify(logger, {level, logger, {Logger, msg, ts, metadata}})
    Process.sleep(100) #GenEvent.notify is async, must wait for IO to appear
  end
end
