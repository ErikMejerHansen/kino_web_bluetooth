defmodule KinoWebBluetooth.Value do
  @moduledoc """
  Converts characteristic values between binaries and the textual
  representations used in the Smart Cell UI.

      iex> KinoWebBluetooth.Value.parse("0a FF", "hex")
      {:ok, <<10, 255>>}

      iex> KinoWebBluetooth.Value.parse("hi", "text")
      {:ok, "hi"}

      iex> KinoWebBluetooth.Value.to_hex(<<10, 255>>)
      "0a ff"

      iex> KinoWebBluetooth.Value.to_text(<<0xFF>>)
      nil

  """

  @formats ["hex", "text"]

  @doc "The input formats supported by `parse/2`."
  @spec formats() :: [String.t()]
  def formats, do: @formats

  @doc """
  Parses user input in the given format (`"hex"` or `"text"`) into a binary.

  Hex input may contain whitespace, `:`, `,` and `0x` prefixes.
  """
  @spec parse(String.t(), String.t()) :: {:ok, binary()} | {:error, String.t()}
  def parse(input, "text") when is_binary(input), do: {:ok, input}

  def parse(input, "hex") when is_binary(input) do
    hex =
      input
      |> String.replace(~r/0x/i, "")
      |> String.replace(~r/[\s:,]/, "")

    case Base.decode16(hex, case: :mixed) do
      {:ok, binary} -> {:ok, binary}
      :error -> {:error, "invalid hex value"}
    end
  end

  def parse(_input, format), do: {:error, "unknown format #{inspect(format)}"}

  @doc "Formats a binary as space separated, lowercase hex bytes."
  @spec to_hex(binary()) :: String.t()
  def to_hex(binary) when is_binary(binary) do
    binary
    |> Base.encode16(case: :lower)
    |> String.replace(~r/(..)(?!$)/, "\\1 ")
  end

  @doc "Returns the binary as text when it is printable UTF-8, otherwise `nil`."
  @spec to_text(binary()) :: String.t() | nil
  def to_text(binary) when is_binary(binary) do
    if binary != "" and String.printable?(binary), do: binary
  end
end
