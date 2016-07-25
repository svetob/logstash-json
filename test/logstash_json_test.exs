defmodule LogstashJsonTest do
  use ExUnit.Case
  require Logger

  doctest LogstashJson.TCP

  test "Happy case" do
    {port, _} = Application.get_env(:logger, :logstash)
      |> Keyword.get(:port)
      |> Integer.parse()

    {:ok, listener} = :gen_tcp.listen(port, [active: false, packet: 0, mode: :binary, reuseaddr: true])
    {:ok, socket} = :gen_tcp.accept listener, 1000
    Logger.info "Hello world!"
    {:ok, msg} = :gen_tcp.recv(socket, 0, 1000)
    :ok = :gen_tcp.close socket
    :ok = :gen_tcp.close listener

    log = Poison.decode!(msg)
    assert Map.get(log, "message") == "Hello world!"
    assert Map.get(log, "level") == "info"
  end
end
