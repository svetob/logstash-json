defmodule LogstashJsonTest do
  use ExUnit.Case
  require Logger
  
  doctest LogstashJson.TCP

  test "Happy-face" do
    Logger.info "Hello World!"
  end
end
