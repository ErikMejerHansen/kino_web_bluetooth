defmodule KinoWebBluetooth.ValueTest do
  use ExUnit.Case, async: true

  alias KinoWebBluetooth.Value

  doctest Value

  describe "parsing hex input" do
    test "ignores separators and 0x prefixes" do
      assert Value.parse("0x01:02, 03 0x04", "hex") == {:ok, <<1, 2, 3, 4>>}
    end

    test "rejects odd or non-hex input" do
      assert Value.parse("abc", "hex") == {:error, "invalid hex value"}
      assert Value.parse("zz", "hex") == {:error, "invalid hex value"}
    end
  end

  test "rejects unknown formats" do
    assert Value.parse("1", "base64") == {:error, ~s(unknown format "base64")}
  end

  describe "displaying values" do
    test "shows text only when it is printable" do
      assert Value.to_text("hello") == "hello"
      assert Value.to_text(<<0>>) == nil
      assert Value.to_text("") == nil
    end

    test "shows an empty value as an empty hex string" do
      assert Value.to_hex("") == ""
    end
  end
end
