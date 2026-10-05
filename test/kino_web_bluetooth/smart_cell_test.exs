defmodule KinoWebBluetooth.SmartCellTest do
  use ExUnit.Case, async: true

  import Kino.Test

  alias KinoWebBluetooth.SmartCell

  setup :configure_livebook_bridge

  @heart_rate "0000180d-0000-1000-8000-00805f9b34fb"
  @measurement "00002a37-0000-1000-8000-00805f9b34fb"
  @control_point "00002a39-0000-1000-8000-00805f9b34fb"
  @location "00002a38-0000-1000-8000-00805f9b34fb"

  @browser_device %{
    "name" => "Polar H10",
    "services" => [
      %{
        "uuid" => @heart_rate,
        "characteristics" => [
          %{"uuid" => @measurement, "properties" => ["notify"]},
          %{"uuid" => @control_point, "properties" => ["write"]},
          %{"uuid" => @location, "properties" => ["read", "unknown_property"]}
        ]
      }
    ]
  }

  describe "a new cell" do
    test "binds a device to a variable" do
      {_kino, source} = start_smart_cell!(SmartCell, %{})

      assert source =~ ~r/^device\d* = KinoWebBluetooth.device\("ble-[\w-]+"\)$/
    end

    test "shows a disconnected device" do
      {kino, _source} = start_smart_cell!(SmartCell, %{})

      assert %{device: %{status: :disconnected, services: []}} = connect(kino)
    end
  end

  describe "a saved cell" do
    test "restores the user input" do
      attrs = %{
        "device_id" => "ble-saved",
        "variable" => "sensor",
        "service_uuid" => "heart_rate",
        "writes" => %{"some/key" => %{"value" => "01", "format" => "hex"}}
      }

      {kino, source} = start_smart_cell!(SmartCell, attrs)

      assert source == ~s/sensor = KinoWebBluetooth.device("ble-saved")/
      assert %{fields: %{variable: "sensor", service_uuid: "heart_rate"}} = connect(kino)
    end
  end

  describe "editing the fields" do
    test "persists the service UUID" do
      {kino, _source} = start_smart_cell!(SmartCell, %{})

      push_event(kino, "update_field", %{"field" => "service_uuid", "value" => " heart_rate "})

      assert_smart_cell_update(kino, %{"service_uuid" => "heart_rate"}, _source)
      assert_broadcast_event(kino, "fields", %{service_uuid: "heart_rate"})
    end

    test "renames the variable in the generated code" do
      {kino, _source} = start_smart_cell!(SmartCell, %{"device_id" => "ble-rename"})

      push_event(kino, "update_field", %{"field" => "variable", "value" => "heart"})

      assert_smart_cell_update(
        kino,
        %{"variable" => "heart"},
        ~s/heart = KinoWebBluetooth.device("ble-rename")/
      )
    end

    test "rejects invalid variable names" do
      {kino, _source} = start_smart_cell!(SmartCell, %{"variable" => "device"})

      push_event(kino, "update_field", %{"field" => "variable", "value" => "1nvalid"})

      assert_broadcast_event(kino, "fields", %{variable: "device"})
    end
  end

  describe "connecting in the browser" do
    test "shows the services and characteristics of the device" do
      {_kino, _source, view} = given_a_connected_cell()

      assert %{
               status: :connected,
               name: "Polar H10",
               services: [
                 %{uuid: @heart_rate, name: "heart_rate", characteristics: characteristics}
               ]
             } = view

      assert [
               %{name: "heart_rate_measurement", properties: [:notify], value_hex: nil},
               %{name: "heart_rate_control_point", properties: [:write]},
               %{name: "body_sensor_location", properties: [:read]}
             ] = characteristics
    end

    test "makes the device available to code" do
      {_kino, source, _view} = given_a_connected_cell()

      device = evaluate(source)

      assert KinoWebBluetooth.connected?(device)
      assert {:ok, _} = KinoWebBluetooth.characteristic(device, "heart_rate_measurement")
    end

    test "shows errors reported by the browser" do
      {kino, _source} = start_smart_cell!(SmartCell, %{})
      connect(kino)

      push_event(kino, "connect_error", %{
        "message" => "User cancelled the requestDevice() chooser."
      })

      assert_broadcast_event(kino, "device", %{
        status: :disconnected,
        error: "User cancelled the requestDevice() chooser."
      })
    end

    test "shows when the device disconnects" do
      {kino, _source, _view} = given_a_connected_cell()

      push_event(kino, "disconnected", %{})

      assert_broadcast_event(kino, "device", %{status: :disconnected, services: []})
    end
  end

  describe "using the API" do
    test "forwards operations to the browser and shows the result" do
      {kino, source, _view} = given_a_connected_cell()
      location = KinoWebBluetooth.characteristic!(evaluate(source), "body_sensor_location")

      reading = Task.async(fn -> KinoWebBluetooth.read(location) end)

      assert_send_event(kino, "request", %{op: "read", ref: ref, characteristic: @location})
      push_event(kino, "response", response(ref, @location, %{"value" => [1]}))

      assert Task.await(reading) == {:ok, <<1>>}
      assert_broadcast_event(kino, "characteristic", %{key: _, value_hex: "01"})
    end

    test "can disconnect the device" do
      {kino, source, _view} = given_a_connected_cell()

      assert KinoWebBluetooth.disconnect(evaluate(source)) == :ok

      assert_send_event(kino, "request", %{op: "disconnect"})
      assert_broadcast_event(kino, "device", %{status: :disconnected})
    end
  end

  describe "using the UI" do
    test "reads a characteristic" do
      {kino, _source, _view} = given_a_connected_cell()

      push_event(kino, "read", %{"key" => key(@location)})

      assert_send_event(kino, "request", %{op: "read", ref: ref})
      push_event(kino, "response", response(ref, @location, %{"value" => ~c"chest"}))

      assert_broadcast_event(kino, "characteristic", %{
        value_hex: "63 68 65 73 74",
        value_text: "chest"
      })
    end

    test "writes and persists the entered value" do
      {kino, _source, _view} = given_a_connected_cell()
      write = %{"value" => "01 ff", "format" => "hex"}

      push_event(kino, "update_write", Map.put(write, "key", key(@control_point)))
      push_event(kino, "write", %{"key" => key(@control_point)})

      assert_smart_cell_update(kino, %{"writes" => %{}}, _source)
      assert_send_event(kino, "request", %{op: "write", value: [1, 255]})
    end

    test "shows invalid input instead of writing it" do
      {kino, _source, _view} = given_a_connected_cell()

      push_event(kino, "update_write", %{
        "key" => key(@control_point),
        "value" => "nope",
        "format" => "hex"
      })

      push_event(kino, "write", %{"key" => key(@control_point)})

      assert_broadcast_event(kino, "characteristic", %{error: "invalid hex value"})
      refute_receive {:event, "request", _, _}
    end

    test "subscribes and shows notified values" do
      {kino, _source, _view} = given_a_connected_cell()

      push_event(kino, "subscribe", %{"key" => key(@measurement), "enabled" => true})

      assert_send_event(kino, "request", %{op: "start_notifications", ref: ref})
      push_event(kino, "response", response(ref, @measurement, %{"value" => nil}))
      assert_broadcast_event(kino, "characteristic", %{notifying: true, ui_subscribed: true})

      push_event(kino, "notification", response(nil, @measurement, %{"value" => [0, 72]}))
      assert_broadcast_event(kino, "characteristic", %{value_hex: "00 48"})
    end
  end

  defp given_a_connected_cell do
    {kino, source} = start_smart_cell!(SmartCell, %{})
    connect(kino)
    push_event(kino, "connected", @browser_device)
    assert_broadcast_event(kino, "device", %{status: :connected} = view)
    {kino, source, view}
  end

  defp evaluate(source) do
    {device, _binding} = Code.eval_string(source)
    device
  end

  defp key(uuid), do: @heart_rate <> "/" <> uuid

  defp response(ref, characteristic, result) do
    Map.merge(
      %{"ref" => ref, "service" => @heart_rate, "characteristic" => characteristic},
      result
    )
  end
end
