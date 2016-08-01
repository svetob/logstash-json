defmodule LogstashJsonTest do
  use ExUnit.Case, async: false
  require Logger

  doctest LogstashJson.TCP

  test "Happy case" do
    {:ok, listener} = :gen_tcp.listen 0, [:binary, {:active, false}, {:packet, 0}, {:reuseaddr, true}]
    {:ok, port} = :inet.port listener
    Logger.configure_backend {LogstashJson.TCP, :logstash}, port: port

    Logger.info "Hello world!"

    {:ok, socket} = :gen_tcp.accept(listener, 1000)
    {:ok, msg} = :gen_tcp.recv(socket, 0, 1000)
    :ok = :gen_tcp.close socket
    :ok = :gen_tcp.close listener

    log = Poison.decode!(msg)
    assert Map.get(log, "message") == "Hello world!"
    assert Map.get(log, "level") == "info"
  end
end
