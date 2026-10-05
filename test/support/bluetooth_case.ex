defmodule KinoWebBluetooth.BluetoothCase do
  @moduledoc """
  Given/when/then helpers for describing behaviour against a fake browser.

  The fake device exposes:

    * `battery_service` with `battery_level` (read, notify)
    * `heart_rate` with `heart_rate_measurement` (notify) and
      `heart_rate_control_point` (write)
    * a UART service with `rx` (write, write without response) and
      `tx` (notify)

  """

  use ExUnit.CaseTemplate

  alias KinoWebBluetooth.{Characteristic, Device, FakeBrowser}

  using do
    quote do
      import KinoWebBluetooth.BluetoothCase
    end
  end

  @uart "6e400001-b5a3-f393-e0a9-e50e24dcca9e"

  @doc "UUID of the custom UART service."
  def uart, do: @uart

  @doc "UUID of the UART `rx` characteristic."
  def uart_rx, do: "6e400002-b5a3-f393-e0a9-e50e24dcca9e"

  @doc "UUID of the UART `tx` characteristic."
  def uart_tx, do: "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

  def services do
    [
      service(0x180F, [{0x2A19, [:read, :notify]}]),
      service(0x180D, [{0x2A37, [:notify]}, {0x2A39, [:write]}]),
      service(@uart, [{uart_rx(), [:write, :write_without_response]}, {uart_tx(), [:notify]}])
    ]
  end

  ## Given

  @doc """
  A device in a Smart Cell, not yet connected.

  `responses` script how the browser answers operations, see
  `KinoWebBluetooth.FakeBrowser`.
  """
  def given_a_device(responses \\ []) do
    id = "ble-test-#{System.unique_integer([:positive])}"

    browser =
      start_supervised!({FakeBrowser, test: self(), device_id: id, responses: responses})

    start_supervised!({Device, id: id, bridge: browser})

    %{device: KinoWebBluetooth.device(id), browser: browser}
  end

  @doc "A device the user connected to in the Smart Cell."
  def given_a_connected_device(responses \\ []) do
    %{device: device} = given = given_a_device(responses)
    when_the_user_connects(device)
    given
  end

  ## When

  @doc "The user picks the device in the browser and it gets connected."
  def when_the_user_connects(device) do
    Device.connected(device, %{name: "Test device", services: services()})
    assert_receive {:kino_web_bluetooth, :device_changed, %{status: :connected}}
  end

  @doc "The browser loses the connection to the device."
  def when_the_device_disconnects(device) do
    Device.disconnected(device)
    assert_receive {:kino_web_bluetooth, :device_changed, %{status: :disconnected}}
  end

  @doc "The browser completes a request it was asked to perform."
  def when_the_browser_completes(char, request, result) do
    Characteristic.deliver(
      char.device_id,
      char.service,
      char.uuid,
      {:response, request.ref, result}
    )
  end

  @doc "The device notifies a new value."
  def when_the_device_notifies(char, value) do
    Characteristic.deliver(char.device_id, char.service, char.uuid, {:notification, value})
  end

  ## Then

  @doc "Asserts the browser was asked to perform `op` and returns the request."
  defmacro assert_browser_request(op, timeout \\ 100) do
    quote do
      assert_receive {:browser_request, %{op: unquote(op)} = request}, unquote(timeout)
      request
    end
  end

  @doc "Asserts the browser was not asked to perform `op`."
  defmacro refute_browser_request(op, timeout \\ 50) do
    quote do
      refute_receive {:browser_request, %{op: unquote(op)}}, unquote(timeout)
    end
  end

  defp service(uuid, characteristics) do
    %{
      uuid: uuid!(uuid),
      characteristics:
        for {char, properties} <- characteristics do
          %{uuid: uuid!(char), properties: properties}
        end
    }
  end

  defp uuid!(uuid) do
    {:ok, uuid} = KinoWebBluetooth.UUID.normalize(uuid)
    uuid
  end
end
