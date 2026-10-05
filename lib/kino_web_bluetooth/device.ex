defmodule KinoWebBluetooth.Device do
  @moduledoc """
  A Bluetooth device selected through a Smart Cell.

  The struct is a handle, used with the functions in `KinoWebBluetooth`.
  It identifies the Smart Cell rather than a physical device, so it stays
  valid across disconnects and reconnects.

  Behind the handle runs a `GenServer` that owns the connection state
  and starts one `KinoWebBluetooth.Characteristic` server per discovered
  characteristic.
  """

  use GenServer

  alias KinoWebBluetooth.Characteristic

  @enforce_keys [:id]
  defstruct [:id]

  @type t :: %__MODULE__{id: String.t()}

  @type service :: %{uuid: String.t(), characteristics: [Characteristic.t()]}

  @type info :: %{
          id: String.t(),
          status: :connected | :disconnected,
          name: String.t() | nil,
          services: [service()]
        }

  ## Client (used by KinoWebBluetooth and the Smart Cell)

  @doc false
  def start_link(opts) do
    id = Keyword.fetch!(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: via(id))
  end

  @doc false
  def whereis(%__MODULE__{id: id}) do
    case Registry.lookup(KinoWebBluetooth.Registry, {:device, id}) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  @doc false
  def info(device), do: call(device, :info, 5_000)

  @doc false
  def await_connected(device, timeout), do: call(device, :await_connected, timeout)

  @doc false
  def disconnect(device), do: call(device, :disconnect, 5_000)

  @doc false
  # Called by the bridge once the browser connected to a device and
  # discovered its services. `info` has the shape of `t:info/0`, with
  # plain maps in place of characteristic structs.
  def connected(device, info), do: cast(device, {:connected, info})

  @doc false
  # Called by the bridge when the browser lost the GATT connection.
  def disconnected(device), do: cast(device, :disconnected)

  defp call(device, message, timeout) do
    case whereis(device) do
      nil ->
        {:error, :not_found}

      pid ->
        try do
          GenServer.call(pid, message, timeout)
        catch
          :exit, {:timeout, _} -> {:error, :timeout}
          :exit, _ -> {:error, :not_found}
        end
    end
  end

  defp cast(device, message) do
    if pid = whereis(device), do: GenServer.cast(pid, message)
    :ok
  end

  defp via(id), do: {:via, Registry, {KinoWebBluetooth.Registry, {:device, id}}}

  ## Server

  @impl true
  def init(opts) do
    bridge = Keyword.fetch!(opts, :bridge)

    {:ok,
     %{
       id: Keyword.fetch!(opts, :id),
       bridge: bridge,
       bridge_ref: Process.monitor(bridge),
       status: :disconnected,
       name: nil,
       services: [],
       characteristic_pids: [],
       waiters: []
     }}
  end

  @impl true
  def handle_call(:info, _from, state), do: {:reply, {:ok, snapshot(state)}, state}

  def handle_call(:await_connected, from, state) do
    case state.status do
      :connected -> {:reply, :ok, state}
      :disconnected -> {:noreply, update_in(state.waiters, &[from | &1])}
    end
  end

  def handle_call(:disconnect, _from, %{status: :connected} = state) do
    send(state.bridge, {:kino_web_bluetooth, :request, %{ref: nil, op: :disconnect}})
    {:reply, :ok, mark_disconnected(state)}
  end

  def handle_call(:disconnect, _from, state), do: {:reply, {:error, :not_connected}, state}

  @impl true
  def handle_cast({:connected, info}, state) do
    state = stop_characteristics(state)

    services =
      for service <- info.services do
        characteristics =
          for char <- service.characteristics do
            %Characteristic{
              device_id: state.id,
              service: service.uuid,
              uuid: char.uuid,
              properties: char.properties
            }
          end

        %{uuid: service.uuid, characteristics: characteristics}
      end

    pids =
      for service <- services, char <- service.characteristics do
        child = {Characteristic, characteristic: char, device: self(), bridge: state.bridge}

        {:ok, pid} =
          DynamicSupervisor.start_child(KinoWebBluetooth.CharacteristicSupervisor, child)

        pid
      end

    for from <- state.waiters, do: GenServer.reply(from, :ok)

    state = %{
      state
      | status: :connected,
        name: info.name,
        services: services,
        characteristic_pids: pids,
        waiters: []
    }

    {:noreply, changed(state)}
  end

  def handle_cast(:disconnected, %{status: :connected} = state) do
    {:noreply, mark_disconnected(state)}
  end

  def handle_cast(:disconnected, state), do: {:noreply, state}

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{bridge_ref: ref} = state) do
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, state) do
    stop_characteristics(state)
    :ok
  end

  defp mark_disconnected(state) do
    state = stop_characteristics(state)
    changed(%{state | status: :disconnected, services: []})
  end

  defp stop_characteristics(state) do
    for pid <- state.characteristic_pids do
      try do
        GenServer.stop(pid, :normal)
      catch
        :exit, _ -> :ok
      end
    end

    %{state | characteristic_pids: []}
  end

  defp changed(state) do
    send(state.bridge, {:kino_web_bluetooth, :device_changed, snapshot(state)})
    state
  end

  defp snapshot(state), do: Map.take(state, [:id, :status, :name, :services])
end
