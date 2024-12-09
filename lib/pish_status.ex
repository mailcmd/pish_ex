defmodule PISH.Status do
  use Agent

  def start_link(inival \\ %{}) do
    Agent.start_link(fn -> inival end)
  end

  def set(pid, key, val) do
    Agent.update(pid, fn status -> Map.put(status, key, val) end)
  end

  def get(pid, key) do
    Agent.get(pid, fn status -> Map.get(status, key) end)
  end

end
