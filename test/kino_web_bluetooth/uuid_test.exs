defmodule KinoWebBluetooth.UUIDTest do
  use ExUnit.Case, async: true

  alias KinoWebBluetooth.UUID

  doctest UUID

  describe "normalizing a UUID" do
    test "expands 16 and 32-bit aliases to the Bluetooth base UUID" do
      assert UUID.normalize("180D") == {:ok, "0000180d-0000-1000-8000-00805f9b34fb"}
      assert UUID.normalize("0x0000180d") == {:ok, "0000180d-0000-1000-8000-00805f9b34fb"}
      assert UUID.normalize(0x12345678) == {:ok, "12345678-0000-1000-8000-00805f9b34fb"}
    end

    test "resolves names only of the requested kind" do
      assert {:ok, _} = UUID.normalize("battery_level", :characteristic)
      assert UUID.normalize("battery_level", :service) == :error
      assert {:ok, _} = UUID.normalize(" Heart_Rate ", :service)
    end

    test "rejects anything else" do
      assert UUID.normalize("18d") == :error
      assert UUID.normalize("not-a-uuid") == :error
      assert UUID.normalize(-1) == :error
      assert UUID.normalize(nil) == :error
    end
  end

  describe "naming a UUID" do
    test "returns nil for unknown UUIDs" do
      assert UUID.name("6e400001-b5a3-f393-e0a9-e50e24dcca9e") == nil
    end
  end
end
