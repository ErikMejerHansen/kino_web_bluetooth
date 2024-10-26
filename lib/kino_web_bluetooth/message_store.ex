defmodule KinoWebBluetooth.MessageStore do
  use Agent

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  @spec add_message(any()) :: :ok
  def add_message(message) do
    Agent.update(__MODULE__, fn state -> Enum.concat(state, [message]) end)
  end

  def messages do
    Agent.get(__MODULE__, fn state -> state end)
  end
end
