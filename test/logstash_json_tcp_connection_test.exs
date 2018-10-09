defmodule LogstashJsonTcpConnectionTest do
  use ExUnit.Case, async: false
  require Logger

  test "Sends message when connection open" do
    {listener, port} = new_listener()

    {:ok, queue} = BlockingQueue.start_link(1)
    {:ok, conn} = LogstashJson.TCP.Connection.start_link('localhost', port, queue)
    LogstashJson.TCP.Connection.send(conn, "foobar")

    msg = recv_and_close(listener)
    assert msg == "foobar"
  end

  test "Drops data when no connection" do
    {:ok, queue} = BlockingQueue.start_link(3)
    {:ok, conn} = LogstashJson.TCP.Connection.start_link('localhost', 1, queue)
    LogstashJson.TCP.Connection.send(conn, "One\n")
    LogstashJson.TCP.Connection.send(conn, "Two\n")

    {listener, port} = new_listener()
    LogstashJson.TCP.Connection.configure(conn, 'localhost', port)

    {:ok, socket} = :gen_tcp.accept(listener, 1000)
    LogstashJson.TCP.Connection.send(conn, "Three\n")
    {:ok, msg} = :gen_tcp.recv(socket, 0, 5000)
    :ok = :gen_tcp.close(socket)
    :ok = :gen_tcp.close(listener)

    assert msg == "Three\n"
  end

  test "Consumes messages from queue" do
    {listener, port} = new_listener()

    {:ok, queue} = BlockingQueue.start_link(1)
    {:ok, _conn} = LogstashJson.TCP.Connection.start_link('localhost', port, queue)
    BlockingQueue.push(queue, "foobar")

    msg = recv_and_close(listener)
    assert msg == "foobar"
  end

  defp new_listener() do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, {:active, false}, {:packet, 0}, {:reuseaddr, true}])

    {:ok, port} = :inet.port(listener)
    {listener, port}
  end

  defp recv_and_close(listener) do
    {:ok, socket} = :gen_tcp.accept(listener, 1000)
    {:ok, msg} = :gen_tcp.recv(socket, 0, 1000)
    :ok = :gen_tcp.close(socket)
    :ok = :gen_tcp.close(listener)
    msg
  end
end
