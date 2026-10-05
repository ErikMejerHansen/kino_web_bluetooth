# KinoWebBluetooth

A [Livebook](https://livebook.dev) Smart Cell and Elixir API for
Bluetooth Low Energy devices, using the browser's
[Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API).

You pick a device in the Smart Cell. Then you can read, write and
subscribe to its characteristics, either in the cell or from Elixir code.

## Requirements

  * Livebook v0.13 or later
  * A Chromium based browser (Chrome, Edge) with Web Bluetooth enabled

## Installation

```elixir
Mix.install([
  {:kino_web_bluetooth, "~> 0.1"}
])
```

## The Smart Cell

Add a **Web Bluetooth** Smart Cell. Then:

1. Enter a GATT service UUID. This can be a full UUID, a 16-bit alias
   such as `0x180D`, or a standard name such as `heart_rate`.
2. Click **Connect** and pick a device in the browser dialog.
3. The cell lists the services and characteristics of the device. Use
   **Read**, **Subscribe** and **Write** to work with them. Write values
   are entered as hex (`01 ff`) or as text.

The cell saves your input in the notebook. When you evaluate it, the
device is bound to a variable (`device` by default).

## The API

Browsers only let a user pick a device, so you always connect in the
Smart Cell. Everything else also works from code:

```elixir
# Bound by the Smart Cell
device = KinoWebBluetooth.device("ble-...")

# Wait until the device is connected in the Smart Cell
:ok = KinoWebBluetooth.await_connected(device)

# Read
location = KinoWebBluetooth.characteristic!(device, "body_sensor_location")
{:ok, <<sensor_location>>} = KinoWebBluetooth.read(location)

# Write, synchronously or asynchronously
control_point = KinoWebBluetooth.characteristic!(device, "heart_rate_control_point")
:ok = KinoWebBluetooth.write(control_point, <<1>>)
:ok = KinoWebBluetooth.write_async(control_point, <<1>>)

# Subscribe to notifications
measurement = KinoWebBluetooth.characteristic!(device, "heart_rate_measurement")
:ok = KinoWebBluetooth.subscribe(measurement)

receive do
  {:kino_web_bluetooth, :notification, ^measurement, <<_flags, bpm, _rest::binary>>} -> bpm
end

# ...or consume them as a stream
measurement
|> KinoWebBluetooth.stream()
|> Kino.listen(fn <<_flags, bpm, _rest::binary>> -> IO.puts("#{bpm} bpm") end)
```

See the `KinoWebBluetooth` module docs for all functions.

## How it works

Each Smart Cell starts a `KinoWebBluetooth.Device` process. When the
device connects, the Device process starts one
`KinoWebBluetooth.Characteristic` GenServer for each characteristic. That
GenServer holds the last value and the subscribers. It also runs GATT
operations one at a time, because browsers reject concurrent operations
on the same characteristic.

The state lives in Elixir. The browser keeps only what it has to: the
`BluetoothDevice` and its characteristic objects. The Smart Cell sends
operations to the browser tab that connected the device, and sends the
results back.

## Development

```sh
mix deps.get
mix test
```

## License

MIT, see [LICENSE](LICENSE).
