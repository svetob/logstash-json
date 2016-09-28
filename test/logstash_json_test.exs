defmodule LogstashJsonTest do
  use ExUnit.Case, async: false
  require Logger

  doctest LogstashJson.TCP

  test "Happy case" do
    listener = new_listener()

    Logger.info "Hello world!"

    msg = recv_and_close(listener)
    log = Poison.decode!(msg)
    assert Map.get(log, "message") == "Hello world!"
    assert Map.get(log, "level") == "info"
  end

  test "TCP log messages end with newline" do
    listener = new_listener()

    Logger.info "Hello world!"

    msg = recv_and_close(listener)
    assert msg |> String.ends_with?("\n")
  end

  test "Can send several messages" do
    listener = new_listener()

    Logger.info "Hello world!"
    Logger.info "Foo?"
    Logger.info "Bar!"

    # Receive all
    {:ok, socket} = :gen_tcp.accept(listener, 1000)
    msg = recv_all(socket)

    assert msg |> String.contains?("Hello world!")
    assert msg |> String.contains?("Foo?")
    assert msg |> String.contains?("Bar!")

    :ok = :gen_tcp.close socket
    :ok = :gen_tcp.close listener
  end

  defp new_listener() do
    {:ok, listener} = :gen_tcp.listen 0, [:binary, {:active, false}, {:packet, 0}, {:reuseaddr, true}]
    {:ok, port} = :inet.port listener
    Logger.configure_backend {LogstashJson.TCP, :logstash},
      port: port,
      workers: 1
    listener
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
end
