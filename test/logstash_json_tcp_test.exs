defmodule LogstashJsonTcpTest do
  use ExUnit.Case, async: false
  require Logger

  doctest LogstashJson.TCP

  test "Happy case" do
    {listener, logger} = new_backend()

    log(logger, "Hello world!")

    msg = recv_and_close(listener)
    log = Poison.decode!(msg)
    assert Map.get(log, "message") == "Hello world!"
    assert Map.get(log, "level") == "info"

    GenEvent.stop(logger)
  end

  test "TCP log messages end with newline" do
    {listener, logger} = new_backend()

    log(logger, "Hello world!")

    msg = recv_and_close(listener)
    assert msg |> String.ends_with?("\n")

    GenEvent.stop(logger)
  end

  test "Can send several messages" do
    {listener, logger} = new_backend()

    log(logger, "Hello world!")
    log(logger, "Foo?")
    log(logger, "Bar!")

    # Receive all
    {:ok, socket} = :gen_tcp.accept(listener, 1000)
    msg = recv_all(socket)

    assert msg |> String.contains?("Hello world!")
    assert msg |> String.contains?("Foo?")
    assert msg |> String.contains?("Bar!")

    :ok = :gen_tcp.close socket
    :ok = :gen_tcp.close listener

    GenEvent.stop(logger)
  end

  defp new_backend do
    {:ok, listener} = :gen_tcp.listen 0, [:binary, {:active, false}, {:packet, 0}, {:reuseaddr, true}]
    {:ok, port} = :inet.port listener
    {listener, new_logger(port)}
  end

  defp new_logger(port) do
    opts = Application.get_env(:logger, :logstash)
    opts = Keyword.put(opts, :port, "#{port}")
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

  defp log(logger, msg, level \\ :info) do
    ts = {{2017,1,1},{1,2,3,400}}
    GenEvent.notify(logger, {level, logger, {Logger, msg, ts, []}})
  end
end
