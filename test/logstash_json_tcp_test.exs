defmodule LogstashJsonTcpTest do
  use ExUnit.Case, async: false
  require Logger

  @moduledoc """
  Unit tests for TCP logger output.
  """

  test "Happy case" do
    {listener, logger} = new_backend()

    log(logger, "Hello world!")

    msg = recv_and_close(listener)
    GenEvent.stop(logger)

    event = Poison.decode!(msg)
    assert event["message"] == "Hello world!"
    assert event["level"] == "info"
  end

  test "TCP log messages end with newline" do
    {listener, logger} = new_backend()

    log(logger, "Hello world!")

    msg = recv_and_close(listener)
    GenEvent.stop(logger)

    assert msg |> String.ends_with?("\n")
  end

  test "Can send several messages" do
    {listener, logger} = new_backend()

    log(logger, "Hello world!")
    log(logger, "Foo?")
    log(logger, "Bar!")

    # Receive all
    {:ok, socket} = :gen_tcp.accept(listener, 1000)
    msg = recv_all(socket)
    :ok = :gen_tcp.close socket
    :ok = :gen_tcp.close listener
    GenEvent.stop(logger)

    lines = msg |> String.trim() |> String.split("\n") |> List.to_tuple()
    assert tuple_size(lines) == 3
    assert lines |> elem(0) |> Poison.decode! |> Map.get("message") == "Hello world!"
    assert lines |> elem(1) |> Poison.decode! |> Map.get("message") == "Foo?"
    assert lines |> elem(2) |> Poison.decode! |> Map.get("message") == "Bar!"
  end

  test "Sent messages include metadata" do
    {listener, logger} = new_backend()

    log(logger, "Hello world!", :info, [car: "Lamborghini"])

    msg = recv_and_close(listener)
    GenEvent.stop(logger)

    event = Poison.decode!(msg)
    assert event["metadata"]["car"]  == "Lamborghini"
  end

  test "Sent messages include static fields" do
    opts = :logger |> Application.get_env(:logstash) |> Keyword.put(:fields, %{test_field: "test_value"})
    Application.put_env(:logger, :logstash, opts)

    {listener, logger} = new_backend()

    log(logger, "Hello world!", :info, [car: "Lamborghini"])

    msg = recv_and_close(listener)
    GenEvent.stop(logger)

    event = Poison.decode!(msg)
    assert event["test_field"] == "test_value"
  end

  defp new_backend do
    {:ok, listener} = :gen_tcp.listen 0, [:binary, {:active, false}, {:packet, 0}, {:reuseaddr, true}]
    {:ok, port} = :inet.port listener
    {listener, new_logger(port)}
  end

  defp new_logger(port) do
    opts = :logger |> Application.get_env(:logstash) |> Keyword.put(:port, "#{port}")
    Application.put_env(:logger, :logstash, opts)

    {:ok, manager} = GenEvent.start_link()
    GenEvent.add_handler(manager, LogstashJson.TCP, {LogstashJson.TCP, :logstash})
    manager
  end

  defp recv_and_close(listener) do
    {:ok, socket} = :gen_tcp.accept(listener, 1000)
    {:ok, msg} = :gen_tcp.recv(socket, 0, 1000)
    :ok = :gen_tcp.close socket
    :ok = :gen_tcp.close listener
    msg
  end

  defp recv_all(socket) do
    case :gen_tcp.recv(socket, 0, 100) do
      {:ok, msg} -> msg <> recv_all socket
      {:error, :timeout} -> ""
    end
  end

  defp log(logger, msg, level \\ :info, metadata \\ []) do
    ts = {{2017, 1, 1}, {1, 2, 3, 400}}
    GenEvent.notify(logger, {level, logger, {Logger, msg, ts, metadata}})
  end
end
