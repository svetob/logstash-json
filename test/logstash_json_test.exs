defmodule LogstashJsonTest do
  use ExUnit.Case
  doctest Logger.Backends.Logstash

  test "the truth" do
    assert 1 + 1 == 2
  end
end
