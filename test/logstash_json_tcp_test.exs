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
    :gen_event.stop(logger)

    event = Jason.decode!(msg)
    assert event["message"] == "Hello world!"
    assert event["level"] == "info"
  end

  describe "Error logging" do
    setup [:log_to_logstash_tcp]

    test "Log message from throw", %{socket: socket} do
      Task.start(fn -> throw("throw up") end)

      msg = recv_all(socket)

      event = Poison.decode!(msg)
      assert event["message"] =~ "throw up"
      assert event["level"] == "error"
    end

    test "Log message from raise", %{socket: socket} do
      Task.start(fn -> raise "my exception" end)

      msg = recv_all(socket)

      event = Poison.decode!(msg)
      assert event["message"] =~ "my exception"
      assert event["level"] == "error"
    end

    defmodule Blubb do
      require Logger

      def do_logging() do
        Logger.debug("Can you hear me?")
      end
    end

    test "Log message with a module", %{socket: socket} do
      Blubb.do_logging()

      msg = recv_all(socket)

      event = Poison.decode!(msg)
      assert event["message"] =~ "Can you hear me?"
      assert event["level"] == "debug"

      if event["mfa"] do
        assert event["mfa"] == ["Elixir.LogstashJsonTcpTest.Blubb", "do_logging", "0"]
      end
    end

    test "Log message from missing FunctionClauseError", %{socket: socket} do
      Task.start(fn ->
        missing_clause = fn :something -> nil end
        missing_clause.(:not_something)
      end)

      msg = recv_all(socket)

      event = Poison.decode!(msg)
      assert event["message"] =~ "FunctionClauseError"
      assert event["level"] == "error"
    end
  end

  test "TCP log messages end with newline" do
    {listener, logger} = new_backend()

    log(logger, "Hello world!")

    msg = recv_and_close(listener)
    :gen_event.stop(logger)

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
    :ok = :gen_tcp.close(socket)
    :ok = :gen_tcp.close(listener)
    :gen_event.stop(logger)

    lines = msg |> String.trim() |> String.split("\n") |> List.to_tuple()
    assert tuple_size(lines) == 3
    assert lines |> elem(0) |> Jason.decode!() |> Map.get("message") == "Hello world!"
    assert lines |> elem(1) |> Jason.decode!() |> Map.get("message") == "Foo?"
    assert lines |> elem(2) |> Jason.decode!() |> Map.get("message") == "Bar!"
  end

  test "Sent messages include metadata" do
    {listener, logger} = new_backend()

    log(logger, "Hello world!", :info, car: "Lamborghini")

    msg = recv_and_close(listener)
    :gen_event.stop(logger)

    event = Jason.decode!(msg)
    assert event["car"] == "Lamborghini"
  end

  test "Sent messages include static fields" do
    opts =
      :logger
      |> Application.get_env(:logstash)
      |> Keyword.put(:fields, %{test_field: "test_value"})

    Application.put_env(:logger, :logstash, opts)

    {listener, logger} = new_backend()

    log(logger, "Hello world!", :info, car: "Lamborghini")

    msg = recv_and_close(listener)
    :gen_event.stop(logger)

    event = Jason.decode!(msg)
    assert event["test_field"] == "test_value"
  end

  test "Formatter formats message" do
    {listener, logger} = new_backend(:logstash_with_formatter)
    # {listener, logger} = new_backend()

    log(logger, "Hello formatted world!")

    msg = recv_and_close(listener)
    :gen_event.stop(logger)

    event = Jason.decode!(msg)
    assert event["message"] == "Hello formatted world!"
    assert event["level"] == "info"
    assert event["added_by_formatter"] == "I am extra"
  end

  defp new_backend(logger_name \\ :logstash) do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, {:active, false}, {:packet, 0}, {:reuseaddr, true}])

    {:ok, port} = :inet.port(listener)
    {listener, new_logger(port, logger_name)}
  end

  defp new_logger(port, logger_name) do
    opts = :logger |> Application.get_env(logger_name) |> Keyword.put(:port, "#{port}")
    Application.put_env(:logger, logger_name, opts)

    {:ok, manager} = :gen_event.start_link()
    :gen_event.add_handler(manager, LogstashJson.TCP, {LogstashJson.TCP, logger_name})
    manager
  end

  defp recv_and_close(listener) do
    {:ok, socket} = :gen_tcp.accept(listener, 1000)
    {:ok, msg} = :gen_tcp.recv(socket, 0, 1000)
    :ok = :gen_tcp.close(socket)
    :ok = :gen_tcp.close(listener)
    msg
  end

  defp recv_all(socket) do
    case :gen_tcp.recv(socket, 0, 100) do
      {:ok, msg} -> msg <> recv_all(socket)
      {:error, :timeout} -> ""
    end
  end

  defp log(logger, msg, level \\ :info, metadata \\ []) do
    ts = {{2017, 1, 1}, {1, 2, 3, 400}}
    :gen_event.notify(logger, {level, logger, {Logger, msg, ts, metadata}})
  end

  defp log_to_logstash_tcp(_context) do
    # Create listener socket
    {:ok, socket} = :gen_tcp.listen(0, [:binary, packet: :line, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(socket)

    # Put port to logstash config
    previous_opts = Application.get_env(:logger, :logstash)
    new_opts = Keyword.put(previous_opts, :port, "#{port}")
    :ok = Application.put_env(:logger, :logstash, new_opts)

    # Switch backends
    {:ok, _pid} = Logger.add_backend({LogstashJson.TCP, :logstash}, flush: true)
    :ok = Logger.remove_backend({LogstashJson.Console, :json})

    # Accept connections
    {:ok, client} = :gen_tcp.accept(socket)

    # Revert when finished
    on_exit(fn ->
      :gen_tcp.close(socket)
      Logger.remove_backend({LogstashJson.TCP, :logstash})
      Logger.add_backend({LogstashJson.Console, :json})
      :ok = Application.put_env(:logger, :logstash, previous_opts)
    end)

    {:ok, socket: client}
  end
end
