defmodule KinoWebBluetooth.ArchitectureTest do
  use KinoWebBluetooth.BluetoothCase, async: true

  alias KinoWebBluetooth.Characteristic

  describe "the package" do
    @tag spec: "ARCH-1"
    test "is named kino_web_bluetooth" do
      config = Mix.Project.config()

      assert config[:app] == :kino_web_bluetooth
      assert config[:package][:name] in [nil, "kino_web_bluetooth"]
    end

    @tag spec: "ARCH-2"
    test "keeps all modules in the KinoWebBluetooth namespace" do
      {:ok, modules} = :application.get_key(:kino_web_bluetooth, :modules)

      for module <- modules do
        assert module == KinoWebBluetooth or
                 String.starts_with?(inspect(module), "KinoWebBluetooth.")
      end
    end
  end

  describe "the interfaces" do
    @tag spec: "ARCH-3"
    test "include a Smart Cell registered with Livebook" do
      assert Enum.any?(
               Kino.SmartCell.definitions(),
               &match?(%{module: KinoWebBluetooth.SmartCell, name: "Web Bluetooth"}, &1)
             )
    end

    @tag spec: "ARCH-4"
    test "include a documented API module" do
      assert {:docs_v1, _, :elixir, _, %{"en" => _moduledoc}, _, _} =
               Code.fetch_docs(KinoWebBluetooth)

      Code.ensure_loaded!(KinoWebBluetooth)

      for {name, arity} <- [read: 2, write: 3, write_async: 3, subscribe: 2] do
        assert function_exported?(KinoWebBluetooth, name, arity)
      end
    end
  end

  describe "a connected device" do
    @tag spec: "ARCH-5"
    test "runs a GenServer per characteristic" do
      %{device: device} = given_a_connected_device()
      characteristics = KinoWebBluetooth.characteristics(device)

      pids = Enum.map(characteristics, &Characteristic.whereis/1)

      assert length(characteristics) == 5
      assert pids |> Enum.uniq() |> length() == 5
      assert Enum.all?(pids, &Process.alive?/1)

      when_the_device_disconnects(device)

      refute Enum.any?(pids, &Process.alive?/1)
    end
  end
end
