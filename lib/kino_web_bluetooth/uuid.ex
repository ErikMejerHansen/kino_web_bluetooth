defmodule KinoWebBluetooth.UUID do
  @moduledoc """
  Normalizes Bluetooth UUIDs to the canonical, lowercase 128-bit form
  used by browsers.

  Accepts full UUIDs, 16/32-bit aliases as integers (`0x180D`) or hex
  strings (`"180d"`, `"0x180D"`), and the names of common services and
  characteristics (`"heart_rate"`), as defined by the Web Bluetooth spec.

      iex> KinoWebBluetooth.UUID.normalize(0x180D)
      {:ok, "0000180d-0000-1000-8000-00805f9b34fb"}

      iex> KinoWebBluetooth.UUID.normalize("0x2A37")
      {:ok, "00002a37-0000-1000-8000-00805f9b34fb"}

      iex> KinoWebBluetooth.UUID.normalize("6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
      {:ok, "6e400001-b5a3-f393-e0a9-e50e24dcca9e"}

      iex> KinoWebBluetooth.UUID.normalize("heart_rate", :service)
      {:ok, "0000180d-0000-1000-8000-00805f9b34fb"}

      iex> KinoWebBluetooth.UUID.name("00002a19-0000-1000-8000-00805f9b34fb")
      "battery_level"

  """

  @type t :: String.t()
  @type input :: String.t() | non_neg_integer()
  @type kind :: :service | :characteristic | :any

  @base_suffix "-0000-1000-8000-00805f9b34fb"

  @services %{
    "generic_access" => 0x1800,
    "generic_attribute" => 0x1801,
    "immediate_alert" => 0x1802,
    "link_loss" => 0x1803,
    "tx_power" => 0x1804,
    "current_time" => 0x1805,
    "health_thermometer" => 0x1809,
    "device_information" => 0x180A,
    "heart_rate" => 0x180D,
    "battery_service" => 0x180F,
    "blood_pressure" => 0x1810,
    "human_interface_device" => 0x1812,
    "running_speed_and_cadence" => 0x1814,
    "cycling_speed_and_cadence" => 0x1816,
    "cycling_power" => 0x1818,
    "location_and_navigation" => 0x1819,
    "environmental_sensing" => 0x181A,
    "body_composition" => 0x181B,
    "user_data" => 0x181C,
    "weight_scale" => 0x181D,
    "fitness_machine" => 0x1826
  }

  @characteristics %{
    "gap.device_name" => 0x2A00,
    "gap.appearance" => 0x2A01,
    "alert_level" => 0x2A06,
    "tx_power_level" => 0x2A07,
    "battery_level" => 0x2A19,
    "temperature_measurement" => 0x2A1C,
    "system_id" => 0x2A23,
    "model_number_string" => 0x2A24,
    "serial_number_string" => 0x2A25,
    "firmware_revision_string" => 0x2A26,
    "hardware_revision_string" => 0x2A27,
    "software_revision_string" => 0x2A28,
    "manufacturer_name_string" => 0x2A29,
    "current_time" => 0x2A2B,
    "heart_rate_measurement" => 0x2A37,
    "body_sensor_location" => 0x2A38,
    "heart_rate_control_point" => 0x2A39,
    "rsc_measurement" => 0x2A53,
    "csc_measurement" => 0x2A5B,
    "cycling_power_measurement" => 0x2A63,
    "pressure" => 0x2A6D,
    "temperature" => 0x2A6E,
    "humidity" => 0x2A6F,
    "weight_measurement" => 0x2A9D
  }

  @doc """
  Returns `{:ok, uuid}` in canonical form, or `:error`.

  `kind` selects which names are recognized: `:service`,
  `:characteristic` or `:any` (default).
  """
  @spec normalize(input(), kind()) :: {:ok, t()} | :error
  def normalize(input, kind \\ :any)

  def normalize(alias, _kind) when is_integer(alias) and alias in 0..0xFFFFFFFF do
    hex = alias |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(8, "0")
    {:ok, hex <> @base_suffix}
  end

  def normalize(string, kind) when is_binary(string) do
    string = string |> String.trim() |> String.downcase()

    cond do
      Regex.match?(~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/, string) ->
        {:ok, string}

      Regex.match?(~r/^(0x)?([0-9a-f]{4}|[0-9a-f]{8})$/, string) ->
        string |> String.replace_prefix("0x", "") |> String.to_integer(16) |> normalize()

      alias = Map.get(names(kind), string) ->
        normalize(alias)

      true ->
        :error
    end
  end

  def normalize(_other, _kind), do: :error

  @doc """
  Returns the known name of a canonical UUID, or `nil`.
  """
  @spec name(t()) :: String.t() | nil
  def name(uuid) when is_binary(uuid) do
    Enum.find_value(Enum.concat(@services, @characteristics), fn {name, alias} ->
      if normalize(alias) == {:ok, uuid}, do: name
    end)
  end

  defp names(:service), do: @services
  defp names(:characteristic), do: @characteristics
  defp names(:any), do: Map.merge(@characteristics, @services)
end
