defmodule KinoWebBluetooth.SmartCell do
  @moduledoc """
  The **Web Bluetooth** Smart Cell.

  Lets the user pick a BLE device for a service UUID, explore its
  services and characteristics, and read, write and subscribe to them.
  The generated code binds a `KinoWebBluetooth.Device` handle for use
  with the `KinoWebBluetooth` API.

  The cell is also the bridge between Elixir and the browser: the
  `BluetoothDevice` and its characteristic objects can only live in
  JavaScript, so GATT operations requested by the
  `KinoWebBluetooth.Characteristic` servers are forwarded to the browser
  client that connected the device, and results are sent back. All
  other state lives in Elixir.
  """

  use Kino.JS, assets_path: "lib/assets/bluetooth_cell"
  use Kino.JS.Live
  use Kino.SmartCell, name: "Web Bluetooth"

  alias KinoWebBluetooth.{Characteristic, Device, UUID, Value}

  @impl true
  def init(attrs, ctx) do
    device_id = start_device(attrs["device_id"])

    {:ok,
     assign(ctx,
       device_id: device_id,
       variable: Kino.SmartCell.prefixed_var_name("device", attrs["variable"]),
       service_uuid: attrs["service_uuid"] || "",
       writes: attrs["writes"] || %{},
       device: %{status: :disconnected, name: nil, services: []},
       characteristics: %{},
       owner: nil,
       error: nil
     )}
  end

  defp start_device(id) do
    id = id || "ble-" <> Base.url_encode64(:crypto.strong_rand_bytes(6), padding: false)

    case Device.start_link(id: id, bridge: self()) do
      {:ok, _pid} -> id
      # The id is taken, for example by a copy of this cell
      {:error, {:already_started, _pid}} -> start_device(nil)
    end
  end

  @impl true
  def handle_connect(ctx) do
    # The client holding the browser connection has been re-rendered
    # and lost its Bluetooth handles
    if ctx.origin == ctx.assigns.owner, do: Device.disconnected(device(ctx))

    payload = %{
      fields: fields(ctx),
      formats: Value.formats(),
      device: device_view(ctx)
    }

    {:ok, payload, ctx}
  end

  ## Events from the UI

  @impl true
  def handle_event("update_field", %{"field" => "variable", "value" => variable}, ctx) do
    ctx =
      if Kino.SmartCell.valid_variable_name?(variable),
        do: assign(ctx, variable: variable),
        else: ctx

    broadcast_event(ctx, "fields", fields(ctx))
    {:noreply, ctx}
  end

  def handle_event("update_field", %{"field" => "service_uuid", "value" => service_uuid}, ctx) do
    ctx = assign(ctx, service_uuid: String.trim(service_uuid))
    broadcast_event(ctx, "fields", fields(ctx))
    {:noreply, ctx}
  end

  def handle_event("update_write", %{"key" => key, "value" => value, "format" => format}, ctx) do
    write = %{"value" => value, "format" => format}
    ctx = update(ctx, :writes, &Map.put(&1, key, write))
    broadcast_event(ctx, "write_input", %{key: key, write: write})
    {:noreply, ctx}
  end

  def handle_event("read", %{"key" => key}, ctx) do
    with {:ok, char} <- fetch_characteristic(ctx, key), do: Characteristic.ui_read(char)
    {:noreply, ctx}
  end

  def handle_event("write", %{"key" => key}, ctx) do
    write = Map.get(ctx.assigns.writes, key, %{"value" => "", "format" => "hex"})

    ctx =
      case {fetch_characteristic(ctx, key), Value.parse(write["value"], write["format"])} do
        {{:ok, char}, {:ok, value}} ->
          Characteristic.ui_write(char, value)
          ctx

        {{:ok, _char}, {:error, message}} ->
          update_characteristic(ctx, key, %{error: message})

        {:error, _parsed} ->
          ctx
      end

    {:noreply, ctx}
  end

  def handle_event("subscribe", %{"key" => key, "enabled" => enabled?}, ctx) do
    with {:ok, char} <- fetch_characteristic(ctx, key) do
      Characteristic.ui_subscribe(char, enabled?)
    end

    {:noreply, ctx}
  end

  def handle_event("disconnect", %{}, ctx) do
    Device.disconnect(device(ctx))
    {:noreply, ctx}
  end

  ## Events from the browser's Web Bluetooth API

  def handle_event("connected", %{"name" => name, "services" => services}, ctx) do
    info = %{
      name: name,
      services:
        for service <- services do
          %{
            uuid: String.downcase(service["uuid"]),
            characteristics:
              for char <- service["characteristics"] do
                %{uuid: String.downcase(char["uuid"]), properties: properties(char["properties"])}
              end
          }
        end
    }

    Device.connected(device(ctx), info)
    {:noreply, assign(ctx, owner: ctx.origin, error: nil)}
  end

  def handle_event("connect_error", %{"message" => message}, ctx) do
    ctx = assign(ctx, error: message)
    broadcast_event(ctx, "device", device_view(ctx))
    {:noreply, ctx}
  end

  def handle_event("disconnected", %{}, ctx) do
    if ctx.origin == ctx.assigns.owner, do: Device.disconnected(device(ctx))
    {:noreply, ctx}
  end

  def handle_event("response", %{"ref" => ref} = response, ctx) do
    result =
      case response do
        %{"error" => message} -> {:error, message}
        %{"value" => value} -> {:ok, decode_value(value)}
      end

    deliver(ctx, response, {:response, ref, result})
    {:noreply, ctx}
  end

  def handle_event("notification", %{"value" => value} = notification, ctx) do
    deliver(ctx, notification, {:notification, decode_value(value)})
    {:noreply, ctx}
  end

  ## Messages from the Device and Characteristic servers

  @impl true
  def handle_info({:kino_web_bluetooth, :request, request}, ctx) do
    if owner = ctx.assigns.owner do
      send_event(ctx, owner, "request", %{
        ref: request.ref,
        op: Atom.to_string(request.op),
        service: request[:service],
        characteristic: request[:characteristic],
        value: request[:value] && :binary.bin_to_list(request.value)
      })
    else
      if request[:characteristic] do
        Characteristic.deliver(
          ctx.assigns.device_id,
          request.service,
          request.characteristic,
          {:response, request.ref, {:error, :not_connected}}
        )
      end
    end

    {:noreply, ctx}
  end

  def handle_info({:kino_web_bluetooth, :device_changed, info}, ctx) do
    ctx =
      case info.status do
        :connected -> assign(ctx, device: info, characteristics: %{})
        :disconnected -> assign(ctx, device: info, characteristics: %{}, owner: nil)
      end

    broadcast_event(ctx, "device", device_view(ctx))
    {:noreply, ctx}
  end

  def handle_info({:kino_web_bluetooth, :characteristic_changed, change}, ctx) do
    {char, change} = Map.pop(change, :char)

    ctx =
      if char.device_id == ctx.assigns.device_id,
        do: update_characteristic(ctx, key(char), change),
        else: ctx

    {:noreply, ctx}
  end

  ## Source

  @impl true
  def to_attrs(ctx) do
    Map.take(ctx.assigns, [:device_id, :variable, :service_uuid, :writes])
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
  end

  @impl true
  def to_source(attrs) do
    quote do
      unquote(Macro.var(String.to_atom(attrs["variable"]), nil)) =
        KinoWebBluetooth.device(unquote(attrs["device_id"]))
    end
    |> Kino.SmartCell.quoted_to_string()
  end

  ## Helpers

  defp device(ctx), do: %Device{id: ctx.assigns.device_id}

  defp fields(ctx), do: Map.take(ctx.assigns, [:variable, :service_uuid])

  defp key(%{service: service, uuid: uuid}), do: service <> "/" <> uuid

  defp fetch_characteristic(ctx, key) do
    ctx.assigns.device.services
    |> Enum.flat_map(& &1.characteristics)
    |> Enum.find(&(key(&1) == key))
    |> case do
      nil -> :error
      char -> {:ok, char}
    end
  end

  defp update_characteristic(ctx, key, change) do
    ctx =
      update(
        ctx,
        :characteristics,
        &Map.update(&1, key, change, fn old -> Map.merge(old, change) end)
      )

    with {:ok, char} <- fetch_characteristic(ctx, key) do
      broadcast_event(ctx, "characteristic", characteristic_view(ctx, char))
    end

    ctx
  end

  defp deliver(ctx, %{"service" => service, "characteristic" => uuid}, message) do
    Characteristic.deliver(ctx.assigns.device_id, service, uuid, message)
  end

  defp decode_value(bytes) when is_list(bytes), do: :binary.list_to_bin(bytes)
  defp decode_value(nil), do: nil

  defp properties(names) do
    known = Map.new(Characteristic.properties(), &{Atom.to_string(&1), &1})
    for name <- names, property = known[name], do: property
  end

  ## Views sent to the UI (plain maps, JSON encodable)

  defp device_view(ctx) do
    %{device: device, error: error} = ctx.assigns

    %{
      status: device.status,
      name: device.name,
      error: error,
      services:
        for service <- device.services do
          %{
            uuid: service.uuid,
            name: UUID.name(service.uuid),
            characteristics: Enum.map(service.characteristics, &characteristic_view(ctx, &1))
          }
        end
    }
  end

  defp characteristic_view(ctx, char) do
    key = key(char)
    state = Map.get(ctx.assigns.characteristics, key, %{})
    value = state[:value]

    %{
      key: key,
      uuid: char.uuid,
      name: UUID.name(char.uuid),
      properties: char.properties,
      value_hex: value && Value.to_hex(value),
      value_text: value && Value.to_text(value),
      error: state[:error],
      notifying: state[:notifying] || false,
      ui_subscribed: state[:ui_subscribed] || false,
      write: Map.get(ctx.assigns.writes, key, %{"value" => "", "format" => "hex"})
    }
  end
end
