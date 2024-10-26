defmodule KinoWebBluetooth.Application do
  @moduledoc false

  use Application

  @impl true
  @spec start(any(), any()) :: {:error, any()} | {:ok, pid()}
  def start(_type, _args) do
    # Register the SmartCell, so that it appears in the "Smart cell" menu in the Livebook
    Kino.SmartCell.register(KinoWebBluetooth)

    children = []
    opts = [strategy: :one_for_one, name: KinoWebBluetooth.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
