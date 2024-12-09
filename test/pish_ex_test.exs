defmodule PishExTest do
  use ExUnit.Case
  doctest PishEx

  test "greets the world" do
    assert PishEx.hello() == :world
  end
end
