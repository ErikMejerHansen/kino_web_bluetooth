defmodule KinoWebBluetooth.BluetoothWriter do
  use GenServer

  def init(broadcaster) do
    {:ok, broadcaster}
  end

  def send_message(message) do
    GenServer.cast(__MODULE__, {:write, message})
  end

  def handle_cast({:write, message}, broadcaster) do
    broadcaster.("write", message)

    {:noreply, broadcaster}
  end
end
