defmodule LogstashJson.TCP.Connection do
  use Connection
  require Logger

  @moduledoc """
  Uses the Connection API to maintain a tcp connection towards logstash and
  handle connection errors.

  Buffers messages that failed to be sent for any reason, until a maximum buffer
  size is reached after which incoming messages are dropped.
  """

  def start_link(host, port, opts, timeout \\ 1_000, buffer_max \\ 10_000) do
    Connection.start_link(__MODULE__, {host, port, opts, timeout, buffer_max})
  end

  @doc "Asynchronous sending of a message"
  def send(conn, data), do: Connection.cast(conn, {:send, data})

  @doc "Close connection"
  def close(conn), do: Connection.call(conn, :close)

  @doc "Update configuration and reconnect"
  def configure(conn, host, port, opts) do
    Connection.call(conn, {:configure, host, port, opts})
  end

  def init({host, port, opts, timeout, buffer_max}) do
    state = %{
      host: host,
      port: port,
      opts: opts,
      timeout: timeout,
      sock: nil,
      buffer: [],
      buffer_max: buffer_max}
    {:connect, :init, state}
  end

  def connect(_, %{sock: nil, host: host, port: port, opts: opts, timeout: timeout} = state) do
    case :gen_tcp.connect(host, port, [active: false] ++ opts, timeout) do
      {:ok, sock} ->
        {:ok, %{state | sock: sock}}
      {:error, reason} ->
        connect_error_log(reason, host, port)
        {:backoff, 1000, state}
    end
  end

  def disconnect(info, %{sock: sock, host: host, port: port} = state) do
    if sock != nil do
      :ok = :gen_tcp.close(sock)
    end
    case info do
      {:close, from} -> Connection.reply(from, :ok)
      {:error, reason} -> disconnect_error_log(reason, host, port)
    end
    {:connect, :reconnect, %{state | sock: nil}}
  end

  def handle_cast({:send, data}, %{sock: nil} = state) do
    {:noreply, buffer_data(data, state)}
  end

  def handle_cast({:send, data}, %{sock: sock, buffer: buffer} = state) do
    data_send = Enum.join([data | buffer])
    case :gen_tcp.send(sock, data_send) do
      :ok ->
        {:noreply, %{state | buffer: []}}
      {:error, :closed} = error ->
        {:disconnect, error, buffer_data(data, state)}
      {:error, reason} = error ->
        send_error_log(reason)
        {:disconnect, error, buffer_data(data, state)}
    end
  end

  def handle_call(:close, from, state) do
    {:disconnect, {:close, from}, state}
  end

  def handle_call({:configure, host, port, opts}, from, state) do
    {:disconnect, {:close, from}, %{state |
      host: host,
      port: port,
      opts: opts}}
  end

  defp connect_error_log(reason, host, port) do
    reason = :inet.format_error(reason)
    IO.puts "#{__MODULE__}: #{host}:#{inspect port} connection failed: #{reason}"
  end
  defp disconnect_error_log(:closed, host, port) do
    IO.puts "#{__MODULE__}: #{host}:#{inspect port} connection closed"
  end
  defp disconnect_error_log(reason, host, port) do
    reason = :inet.format_error(reason)
    IO.puts "#{__MODULE__}: #{host}:#{inspect port} connection error: #{reason}"
  end
  defp send_error_log(reason) do
    reason = :inet.format_error(reason)
    IO.puts "#{__MODULE__}: error sending over TCP: #{reason}"
  end

  defp buffer_data(data, %{buffer: buffer, buffer_max: max} = state) do
    if length(buffer) < max do
      %{state | buffer: [data | buffer]}
    else
      state
    end
  end
end
