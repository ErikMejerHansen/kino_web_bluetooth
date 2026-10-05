defmodule KinoWebBluetooth.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Kino.SmartCell.register(KinoWebBluetooth.SmartCell)

    children = [
      {Registry, keys: :unique, name: KinoWebBluetooth.Registry},
      {DynamicSupervisor, name: KinoWebBluetooth.CharacteristicSupervisor, strategy: :one_for_one}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: KinoWebBluetooth.Supervisor)
  end
end
