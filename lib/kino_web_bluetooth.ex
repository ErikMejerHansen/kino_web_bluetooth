defmodule KinoWebBluetooth do
  alias KinoWebBluetooth.BluetoothWriter
  alias KinoWebBluetooth.MessageStore
  require Logger

  # Bring in the behaviour and define the text on the Smart Cell button
  use Kino.SmartCell, name: "Web Bluetooth"

  # Use Kino.JS as set the assets path to "assets".
  # Source files placed in the "js" folder will be built and outputted into the "assets" folder via vite
  use Kino.JS, assets_path: "assets"
  use Kino.JS.Live

  @impl Kino.JS.Live
  @spec init(any(), Kino.JS.Live.Context.t()) :: {:ok, Kino.JS.Live.Context.t()}
  def init(attrs, ctx) do
    # Init gets called when the smart-cell is first initialized

    # We need to populate the ctx with the expected assigns
    ctx =
      assign(ctx, gatt_service_uuid: attrs["gatt_service_uuid"] || "", device_connected: false)

    # Start the Agent we'll use for holding the incomming values
    MessageStore.start_link([[]])

    # Start the GenServer we'll use for sending messages to the bluetooth device (via the browser)
    {:ok, _} =
      GenServer.start_link(
        BluetoothWriter,
        fn event, payload ->
          broadcast_message = {:binary, %{value: "write"}, payload}
          broadcast_event(ctx, event, broadcast_message)
        end,
        name: BluetoothWriter
      )

    {:ok, ctx}
  end

  @impl Kino.JS.Live
  def handle_connect(ctx) do
    # Gets called everytime the another browser window opens the Livebook

    # Data returned get passed to JS init function, so that we can restore the saved state in the UI
    {:ok,
     %{
       "gattServiceUUID" => ctx.assigns.gatt_service_uuid,
       "device_connected" => ctx.assigns.device_connected
     }, ctx}
  end

  @impl Kino.SmartCell
  def to_attrs(ctx) do
    # We need to be able to serialise the state of the smart cell in order to save it
    # The serialised state needs to be representable as JSON
    # The values gets saved as base64 encoded JSON in the markdown file
    %{
      "gatt_service_uuid" => ctx.assigns.gatt_service_uuid
    }
  end

  @impl Kino.SmartCell
  def to_source(attrs) do
    # Called when attrs change - allows you to generate code based on the attrs
    quote do
      unquote(quoted_var("service_uuid")) = unquote(attrs["gatt_service_uuid"])
    end
    |> Kino.SmartCell.quoted_to_string()
  end

  defp quoted_var(nil), do: nil
  defp quoted_var(string), do: {String.to_atom(string), [], nil}

  # We'll have one handle_event per type of event sent from the JS client
  # 😍 pattern matching
  @impl Kino.JS.Live
  def handle_event("update_gatt_service", gatt_service_uuid, ctx) do
    # You might want to let the other connected JS clients know that the text changed
    # broadcast_event(ctx, "update_text", text)

    # Save the updated value in the context
    # (this might look familiar if you've worked with Phoenix)
    # We save state by putting into the `assigns` map of the context (just like in a LiveView)
    {:noreply, assign(ctx, gatt_service_uuid: gatt_service_uuid)}
  end

  def handle_event("device_connected", payload, ctx) do
    IO.inspect(payload)
    broadcast_event(ctx, "device_connected", payload)

    # TODO: This will need to have the payload as well so that new connections can get the correct state
    {:noreply, assign(ctx, device_connected: true)}
  end

  @impl Kino.JS.Live
  def handle_event("value_update", {:binary, _info, update}, ctx) do
    # Add the message to our MessageStore so that we can play with it in Elixir
    MessageStore.add_message(update)

    # And let all connected clients know that a new message as appeared
    # use the {:binary, } construct to make sure the data is recieved as a Buffer on the client side
    payload = {:binary, %{value: "message"}, update}
    broadcast_event(ctx, "value_update", payload)

    {:noreply, ctx}
  end
end
