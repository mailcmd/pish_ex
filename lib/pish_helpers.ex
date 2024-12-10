defmodule Pish.Helpers do
  def regex?(value), do: Kernel.is_struct(value, Regex)

  # First non null value
  def fnnv([]), do: nil
  def fnnv([h | _]) when h != nil and h != false and h != "", do: h
  def fnnv([_ | t]), do: fnnv(t)
end
