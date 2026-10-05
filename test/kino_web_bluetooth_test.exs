defmodule KinoWebBluetoothTest do
  use KinoWebBluetooth.BluetoothCase, async: true

  describe "a device that is not connected" do
    @describetag spec: "API-1"

    test "reports that it is disconnected" do
      %{device: device} = given_a_device()

      refute KinoWebBluetooth.connected?(device)
      assert KinoWebBluetooth.services(device) == []
    end

    test "can be awaited until the user connects it" do
      %{device: device} = given_a_device()

      waiting = Task.async(fn -> KinoWebBluetooth.await_connected(device) end)
      when_the_user_connects(device)

      assert Task.await(waiting) == :ok
      assert KinoWebBluetooth.connected?(device)
    end

    test "times out when awaited for too long" do
      %{device: device} = given_a_device()

      assert KinoWebBluetooth.await_connected(device, 10) == {:error, :timeout}
    end

    test "cannot be disconnected" do
      %{device: device} = given_a_device()

      assert KinoWebBluetooth.disconnect(device) == {:error, :not_connected}
    end
  end

  describe "a device without a Smart Cell" do
    @describetag spec: "API-1"

    test "is not found" do
      device = KinoWebBluetooth.device("ble-unknown")

      assert KinoWebBluetooth.info(device) == {:error, :not_found}
      refute KinoWebBluetooth.connected?(device)
    end
  end

  describe "a connected device" do
    @describetag spec: "API-1"

    test "lists its services and characteristics" do
      %{device: device} = given_a_connected_device()

      assert {:ok, %{status: :connected, name: "Test device"}} = KinoWebBluetooth.info(device)

      assert [battery, heart_rate, _uart] = KinoWebBluetooth.services(device)
      assert battery.uuid == "0000180f-0000-1000-8000-00805f9b34fb"
      assert [%{uuid: "00002a19-0000-1000-8000-00805f9b34fb"}] = battery.characteristics
      assert length(heart_rate.characteristics) == 2

      assert length(KinoWebBluetooth.characteristics(device)) == 5
    end

    test "finds characteristics by name, alias or UUID" do
      %{device: device} = given_a_connected_device()

      assert {:ok, by_name} = KinoWebBluetooth.characteristic(device, "battery_level")
      assert {:ok, ^by_name} = KinoWebBluetooth.characteristic(device, 0x2A19)
      assert {:ok, ^by_name} = KinoWebBluetooth.characteristic(device, "battery_service", "2A19")
      assert by_name.properties == [:read, :notify]

      assert {:ok, %{uuid: rx}} = KinoWebBluetooth.characteristic(device, uart(), uart_rx())
      assert rx == uart_rx()
    end

    test "does not find characteristics it does not have" do
      %{device: device} = given_a_connected_device()

      assert KinoWebBluetooth.characteristic(device, "heart_rate", "battery_level") ==
               {:error, :not_found}

      assert KinoWebBluetooth.characteristic(device, "not a uuid") == {:error, :invalid_uuid}
      assert_raise ArgumentError, fn -> KinoWebBluetooth.characteristic!(device, 0x2A00) end
    end

    test "can be disconnected" do
      %{device: device} = given_a_connected_device()
      battery = KinoWebBluetooth.characteristic!(device, "battery_level")

      assert KinoWebBluetooth.disconnect(device) == :ok

      assert_browser_request(:disconnect)
      refute KinoWebBluetooth.connected?(device)
      assert KinoWebBluetooth.read(battery) == {:error, :not_connected}
    end
  end

  describe "reading a characteristic" do
    @describetag spec: "API-4"

    test "returns the value from the device" do
      %{device: device} = given_a_connected_device(read: {:ok, <<87>>})
      battery = KinoWebBluetooth.characteristic!(device, "battery_level")

      assert KinoWebBluetooth.read(battery) == {:ok, <<87>>}

      request = assert_browser_request(:read)
      assert request.service == battery.service
      assert request.characteristic == battery.uuid
    end

    test "returns the error reported by the browser" do
      %{device: device} = given_a_connected_device(read: {:error, "GATT operation failed"})
      battery = KinoWebBluetooth.characteristic!(device, "battery_level")

      assert KinoWebBluetooth.read(battery) == {:error, "GATT operation failed"}
    end

    test "times out when the browser does not answer" do
      %{device: device} = given_a_connected_device(read: :no_reply)
      battery = KinoWebBluetooth.characteristic!(device, "battery_level")

      assert KinoWebBluetooth.read(battery, timeout: 10) == {:error, :timeout}
    end

    test "is refused when the characteristic is not readable" do
      %{device: device} = given_a_connected_device()
      measurement = KinoWebBluetooth.characteristic!(device, "heart_rate_measurement")

      assert KinoWebBluetooth.read(measurement) == {:error, :not_readable}
      refute_browser_request(:read)
    end

    test "fails when the device disconnects while waiting" do
      %{device: device} = given_a_connected_device(read: :no_reply)
      battery = KinoWebBluetooth.characteristic!(device, "battery_level")

      reading = Task.async(fn -> KinoWebBluetooth.read(battery) end)
      assert_browser_request(:read)
      when_the_device_disconnects(device)

      assert Task.await(reading) == {:error, :disconnected}
    end
  end

  describe "writing a characteristic" do
    @describetag spec: "API-3"

    test "sends the value and waits for the device to acknowledge it" do
      %{device: device} = given_a_connected_device()
      control_point = KinoWebBluetooth.characteristic!(device, "heart_rate_control_point")

      assert KinoWebBluetooth.write(control_point, <<1>>) == :ok

      request = assert_browser_request(:write)
      assert request.value == <<1>>
    end

    test "can skip the acknowledgement when the characteristic allows it" do
      %{device: device} = given_a_connected_device()
      rx = KinoWebBluetooth.characteristic!(device, uart(), uart_rx())

      assert KinoWebBluetooth.write(rx, "hello", with_response: false) == :ok

      assert %{value: "hello"} = assert_browser_request(:write_without_response)
    end

    test "accepts iodata" do
      %{device: device} = given_a_connected_device()
      rx = KinoWebBluetooth.characteristic!(device, uart(), uart_rx())

      assert KinoWebBluetooth.write(rx, ["he", ?l, "lo"]) == :ok

      assert %{value: "hello"} = assert_browser_request(:write)
    end

    test "returns the error reported by the browser" do
      %{device: device} = given_a_connected_device(write: {:error, "write not permitted"})
      control_point = KinoWebBluetooth.characteristic!(device, "heart_rate_control_point")

      assert KinoWebBluetooth.write(control_point, <<1>>) == {:error, "write not permitted"}
    end

    test "is refused when the characteristic is not writable" do
      %{device: device} = given_a_connected_device()
      battery = KinoWebBluetooth.characteristic!(device, "battery_level")
      control_point = KinoWebBluetooth.characteristic!(device, "heart_rate_control_point")

      assert KinoWebBluetooth.write(battery, <<1>>) == {:error, :not_writable}

      assert KinoWebBluetooth.write(control_point, <<1>>, with_response: false) ==
               {:error, :not_writable}
    end

    test "asynchronously returns right away" do
      %{device: device} = given_a_connected_device(write: :no_reply)
      rx = KinoWebBluetooth.characteristic!(device, uart(), uart_rx())

      assert KinoWebBluetooth.write_async(rx, "hello") == :ok

      assert %{value: "hello"} = assert_browser_request(:write)
    end

    test "asynchronously still sends one write at a time, in order" do
      %{device: device} = given_a_connected_device(write: :no_reply)
      rx = KinoWebBluetooth.characteristic!(device, uart(), uart_rx())

      KinoWebBluetooth.write_async(rx, "first")
      KinoWebBluetooth.write_async(rx, "second")

      first = assert_browser_request(:write)
      assert first.value == "first"
      refute_browser_request(:write)

      when_the_browser_completes(rx, first, {:ok, nil})

      assert %{value: "second"} = assert_browser_request(:write)
    end
  end

  describe "subscribing to a characteristic" do
    @describetag spec: "API-2"

    test "starts notifications on the device" do
      %{device: device} = given_a_connected_device()
      measurement = KinoWebBluetooth.characteristic!(device, "heart_rate_measurement")

      assert KinoWebBluetooth.subscribe(measurement) == :ok

      assert_browser_request(:start_notifications)
    end

    test "delivers every notified value to the subscriber" do
      %{device: device} = given_a_connected_device()
      measurement = KinoWebBluetooth.characteristic!(device, "heart_rate_measurement")
      :ok = KinoWebBluetooth.subscribe(measurement)

      when_the_device_notifies(measurement, <<0, 72>>)
      when_the_device_notifies(measurement, <<0, 75>>)

      assert_receive {:kino_web_bluetooth, :notification, ^measurement, <<0, 72>>}
      assert_receive {:kino_web_bluetooth, :notification, ^measurement, <<0, 75>>}
    end

    test "starts notifications only once for many subscribers" do
      %{device: device} = given_a_connected_device()
      measurement = KinoWebBluetooth.characteristic!(device, "heart_rate_measurement")

      :ok = KinoWebBluetooth.subscribe(measurement)
      :ok = Task.await(Task.async(fn -> KinoWebBluetooth.subscribe(measurement) end))

      assert_browser_request(:start_notifications)
      refute_browser_request(:start_notifications)
    end

    test "stops notifications when the last subscriber unsubscribes" do
      %{device: device} = given_a_connected_device()
      measurement = KinoWebBluetooth.characteristic!(device, "heart_rate_measurement")
      :ok = KinoWebBluetooth.subscribe(measurement)

      assert KinoWebBluetooth.unsubscribe(measurement) == :ok

      assert_browser_request(:stop_notifications)
      when_the_device_notifies(measurement, <<0, 72>>)
      refute_receive {:kino_web_bluetooth, :notification, _, _}
    end

    test "stops notifications when the subscriber exits" do
      %{device: device} = given_a_connected_device()
      measurement = KinoWebBluetooth.characteristic!(device, "heart_rate_measurement")

      Task.await(Task.async(fn -> KinoWebBluetooth.subscribe(measurement) end))

      assert_browser_request(:start_notifications)
      assert_browser_request(:stop_notifications)
    end

    test "tells the subscriber when the device disconnects" do
      %{device: device} = given_a_connected_device()
      measurement = KinoWebBluetooth.characteristic!(device, "heart_rate_measurement")
      :ok = KinoWebBluetooth.subscribe(measurement)

      when_the_device_disconnects(device)

      assert_receive {:kino_web_bluetooth, :disconnected, ^measurement}
    end

    test "fails when the browser cannot start notifications" do
      %{device: device} =
        given_a_connected_device(start_notifications: {:error, "notifications not supported"})

      measurement = KinoWebBluetooth.characteristic!(device, "heart_rate_measurement")

      assert KinoWebBluetooth.subscribe(measurement) == {:error, "notifications not supported"}
    end

    test "is refused when the characteristic does not notify" do
      %{device: device} = given_a_connected_device()
      control_point = KinoWebBluetooth.characteristic!(device, "heart_rate_control_point")

      assert KinoWebBluetooth.subscribe(control_point) == {:error, :not_notifiable}
    end
  end

  describe "streaming a characteristic" do
    @describetag spec: "API-2"

    test "emits notified values until the device disconnects" do
      %{device: device} = given_a_connected_device()
      tx = KinoWebBluetooth.characteristic!(device, uart(), uart_tx())

      streaming = Task.async(fn -> tx |> KinoWebBluetooth.stream() |> Enum.to_list() end)
      assert_browser_request(:start_notifications)

      when_the_device_notifies(tx, "hello ")
      when_the_device_notifies(tx, "world")
      when_the_device_disconnects(device)

      assert Task.await(streaming) == ["hello ", "world"]
    end

    test "unsubscribes when the consumer stops early" do
      %{device: device} = given_a_connected_device()
      tx = KinoWebBluetooth.characteristic!(device, uart(), uart_tx())

      taking = Task.async(fn -> tx |> KinoWebBluetooth.stream() |> Enum.take(1) end)
      assert_browser_request(:start_notifications)
      when_the_device_notifies(tx, "hello")

      assert Task.await(taking) == ["hello"]
      assert_browser_request(:stop_notifications)
    end
  end
end
