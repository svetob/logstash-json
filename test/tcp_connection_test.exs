defmodule TcpConnectionTest do
  use ExUnit.Case, async: false
  require Logger

  @connection_opts [mode: :binary, keepalive: true]

  test "Sends message when connection open" do
    {listener, port} = new_listener()

    {:ok, conn} = LogstashJson.TCP.Connection.start_link('localhost', port, @connection_opts)
    LogstashJson.TCP.Connection.send(conn, "foobar")

    msg = recv_and_close(listener)
    assert msg == "foobar"
  end

  test "Buffers data when no connection, sends buffer when connection opens" do
    {:ok, conn} = LogstashJson.TCP.Connection.start_link('no_such_host', 1, @connection_opts)
    LogstashJson.TCP.Connection.send(conn, "One\n")
    LogstashJson.TCP.Connection.send(conn, "Two\n")

    {listener, port} = new_listener()
    LogstashJson.TCP.Connection.configure(conn, 'localhost', port, @connection_opts)

    LogstashJson.TCP.Connection.send(conn, "Three\n")

    msg = recv_and_close(listener)
    assert msg == "Three\nTwo\nOne\n"
  end

  test "Drops message if buffer full" do
    {:ok, conn} = LogstashJson.TCP.Connection.start_link('no_such_host', 1, @connection_opts, 1000, 2)
    LogstashJson.TCP.Connection.send(conn, "One\n")
    LogstashJson.TCP.Connection.send(conn, "Two\n")
    LogstashJson.TCP.Connection.send(conn, "Three\n")
    LogstashJson.TCP.Connection.send(conn, "Four")

    {listener, port} = new_listener()
    LogstashJson.TCP.Connection.configure(conn, 'localhost', port, @connection_opts)

    LogstashJson.TCP.Connection.send(conn, "Hello\n")

    msg = recv_and_close(listener)
    assert msg == "Hello\nTwo\nOne\n"
  end

  defp new_listener() do
    {:ok, listener} = :gen_tcp.listen 0, [:binary, {:active, false}, {:packet, 0}, {:reuseaddr, true}]
    {:ok, port} = :inet.port listener
    {listener, port}
  end

  defp recv_and_close(listener) do
    {:ok, socket} = :gen_tcp.accept(listener, 1000)
    {:ok, msg} = :gen_tcp.recv(socket, 0, 1000)
    :ok = :gen_tcp.close socket
    :ok = :gen_tcp.close listener
    msg
  end
end
