defmodule KinoWebBluetooth do
  @moduledoc """
  Web Bluetooth (BLE GATT) for Livebook.

  Add the **Web Bluetooth** Smart Cell to a notebook, enter a service
  UUID and click **Connect**. Browsers only let a user pick a device, so
  connecting always happens in the Smart Cell. Everything else can be
  done from code, using the device bound by the cell:

      device = KinoWebBluetooth.device("ble-...")
      :ok = KinoWebBluetooth.await_connected(device)

      {:ok, battery} = KinoWebBluetooth.characteristic(device, "battery_level")
      {:ok, <<level>>} = KinoWebBluetooth.read(battery)

  ## Services and characteristics

  A device has services, and a service has characteristics. Use
  `services/1` to walk that hierarchy. `characteristics/1` and
  `characteristic/3` are shortcuts that look across all services, so
  the service is optional; pass it only to tell apart characteristics
  that share a UUID in different services.

  ## UUIDs

  Services and characteristics are identified by UUIDs. Functions
  accept full UUIDs, 16/32-bit aliases (`0x2A19`, `"2a19"`) and common
  names like `"battery_level"`, see `KinoWebBluetooth.UUID`.

  ## Notifications

  Subscribers receive messages for every value the device sends:

      {:kino_web_bluetooth, :notification, characteristic, value}

  and, when the device disconnects:

      {:kino_web_bluetooth, :disconnected, characteristic}

  ## Errors

  Operations return `{:error, reason}`, where `reason` is one of
  `:not_found`, `:not_connected`, `:disconnected`, `:timeout`,
  `:not_readable`, `:not_writable`, `:not_notifiable`, or a message
  from the browser.
  """

  alias KinoWebBluetooth.{Characteristic, Device, UUID}

  @type error :: {:error, atom() | String.t()}

  @doc """
  Returns the device handle for a Smart Cell's device id.

  The Smart Cell generates this call for you.
  """
  @spec device(String.t()) :: Device.t()
  def device(id) when is_binary(id), do: %Device{id: id}

  @doc """
  Returns information about the device and its services.
  """
  @spec info(Device.t()) :: {:ok, Device.info()} | error()
  def info(%Device{} = device), do: Device.info(device)

  @doc """
  Returns `true` when the device is connected.
  """
  @spec connected?(Device.t()) :: boolean()
  def connected?(%Device{} = device), do: match?({:ok, %{status: :connected}}, info(device))

  @doc """
  Blocks until the device is connected through the Smart Cell.

  Returns `:ok` immediately if it is connected already.
  """
  @spec await_connected(Device.t(), timeout()) :: :ok | error()
  def await_connected(%Device{} = device, timeout \\ :infinity) do
    Device.await_connected(device, timeout)
  end

  @doc """
  Disconnects the device.
  """
  @spec disconnect(Device.t()) :: :ok | error()
  def disconnect(%Device{} = device), do: Device.disconnect(device)

  @doc """
  Lists the services of the connected device, each with its characteristics.
  """
  @spec services(Device.t()) :: [Device.service()]
  def services(%Device{} = device) do
    case info(device) do
      {:ok, info} -> info.services
      _error -> []
    end
  end

  @doc """
  Lists all characteristics of the connected device, across all services.

  A device has services and a service has characteristics. This is a
  shortcut that flattens that hierarchy; each characteristic still knows
  its `service`. Use `services/1` to keep the hierarchy.
  """
  @spec characteristics(Device.t()) :: [Characteristic.t()]
  def characteristics(%Device{} = device) do
    Enum.flat_map(services(device), & &1.characteristics)
  end

  @doc """
  Finds a characteristic by UUID, optionally within the given service.

  The hierarchy is device, services, characteristics, but the service is
  optional here since characteristic UUIDs are usually unique on a device.
  Pass the service to tell apart characteristics that share a UUID across
  services.

      {:ok, char} = KinoWebBluetooth.characteristic(device, 0x2A37)
      {:ok, char} = KinoWebBluetooth.characteristic(device, "heart_rate", "heart_rate_measurement")

  """
  @spec characteristic(Device.t(), UUID.input(), UUID.input()) ::
          {:ok, Characteristic.t()} | error()
  def characteristic(device, service \\ nil, uuid)

  def characteristic(%Device{} = device, service, uuid) do
    with {:ok, uuid} <- normalize(uuid, :characteristic),
         {:ok, service} <- normalize_service(service) do
      device
      |> characteristics()
      |> Enum.find(&(&1.uuid == uuid and (service == nil or &1.service == service)))
      |> case do
        nil -> {:error, :not_found}
        char -> {:ok, char}
      end
    end
  end

  @doc """
  Same as `characteristic/3`, but raises if the characteristic is not found.
  """
  @spec characteristic!(Device.t(), UUID.input(), UUID.input()) :: Characteristic.t()
  def characteristic!(device, service \\ nil, uuid) do
    case characteristic(device, service, uuid) do
      {:ok, char} ->
        char

      {:error, reason} ->
        raise ArgumentError, "characteristic #{inspect(uuid)} not available: #{inspect(reason)}"
    end
  end

  @doc """
  Reads the current value of a characteristic.

  ## Options

    * `:timeout` - how long to wait for the device, defaults to `5_000` ms

  """
  @spec read(Characteristic.t(), keyword()) :: {:ok, binary()} | error()
  def read(%Characteristic{} = char, opts \\ []), do: Characteristic.read(char, opts)

  @doc """
  Writes a value to a characteristic and waits for it to complete.

  ## Options

    * `:with_response` - whether the device acknowledges the write.
      Defaults to `true` when the characteristic supports it

    * `:timeout` - how long to wait for the device, defaults to `5_000` ms

  """
  @spec write(Characteristic.t(), iodata(), keyword()) :: :ok | error()
  def write(%Characteristic{} = char, value, opts \\ []) do
    Characteristic.write(char, value, opts)
  end

  @doc """
  Writes a value to a characteristic without waiting for it to complete.

  Writes are still sent in order. Failures are logged and shown in the
  Smart Cell. Accepts the same options as `write/3`, except `:timeout`.
  """
  @spec write_async(Characteristic.t(), iodata(), keyword()) :: :ok | error()
  def write_async(%Characteristic{} = char, value, opts \\ []) do
    Characteristic.write_async(char, value, opts)
  end

  @doc """
  Subscribes the calling process to notifications from a characteristic.

  Starts notifications on the device if needed. See the "Notifications"
  section in the module docs for the messages sent.
  """
  @spec subscribe(Characteristic.t(), keyword()) :: :ok | error()
  def subscribe(%Characteristic{} = char, opts \\ []) do
    Characteristic.subscribe(char, self(), opts)
  end

  @doc """
  Unsubscribes the calling process from a characteristic.

  Stops notifications on the device once nobody is subscribed.
  """
  @spec unsubscribe(Characteristic.t()) :: :ok | error()
  def unsubscribe(%Characteristic{} = char), do: Characteristic.unsubscribe(char, self())

  @doc """
  Returns a stream of notification values from a characteristic.

  The stream subscribes when consumed and halts when the device
  disconnects. It works well with `Kino.listen/2`:

      char
      |> KinoWebBluetooth.stream()
      |> Kino.listen(fn value -> IO.inspect(value) end)

  """
  @spec stream(Characteristic.t()) :: Enumerable.t()
  def stream(%Characteristic{} = char) do
    Stream.resource(
      fn ->
        case subscribe(char) do
          :ok -> char
          {:error, reason} -> raise ArgumentError, "could not subscribe: #{inspect(reason)}"
        end
      end,
      fn char ->
        receive do
          {:kino_web_bluetooth, :notification, ^char, value} -> {[value], char}
          {:kino_web_bluetooth, :disconnected, ^char} -> {:halt, char}
        end
      end,
      fn char -> unsubscribe(char) end
    )
  end

  defp normalize(uuid, kind) do
    case UUID.normalize(uuid, kind) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, :invalid_uuid}
    end
  end

  defp normalize_service(nil), do: {:ok, nil}
  defp normalize_service(service), do: normalize(service, :service)
end
