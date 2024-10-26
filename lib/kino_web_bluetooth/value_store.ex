defmodule KinoWebBluetooth.ValueStore do
  use GenServer

  @impl GenServer
  def init(_init) do
    {:ok, []}
  end

  @impl GenServer
  def handle_cast({:push, value}, state) do
    {:noreply, [value | state]}
  end

  @impl GenServer
  def handle_call(:get_values, _from, state) do
    {:reply, state, state}
  end

  def push_value(pid, value) do
    GenServer.cast(pid, {:push, value})
  end

  def get_values(pid) do
    GenServer.call(pid, :get_values)
  end
end
