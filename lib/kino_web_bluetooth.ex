defmodule KinoWebBluetooth do
  alias KinoWebBluetooth.ValueStore
  require Logger
  # Bring in the behaviour and define the text on the Smart Cell button
  use Kino.SmartCell, name: "Web Bluetooth"

  # Use Kino.JS as set the assets path to "assets".
  # Source files placed in the "js" folder will be built and outputted into the "assets" folder via esbuild
  use Kino.JS, assets_path: "assets"
  use Kino.JS.Live

  @impl Kino.JS.Live
  @spec init(any(), Kino.JS.Live.Context.t()) :: {:ok, Kino.JS.Live.Context.t()}
  def init(attrs, ctx) do
    # Init gets called when the smart-cell is first initialized

    # We need to populate the ctx with the expected assigns
    ctx = assign(ctx, gatt_service_uuid: attrs["gatt_service_uuid"] || "")
    ctx = assign(ctx, gatt_characteristic_uuid: attrs["gatt_characteristic_uuid"] || "")
    ctx = assign(ctx, variable_name: attrs["variable_name"] || "")

    # Start the GenServer we'll use for holding the incomming values
    {:ok, pid} = GenServer.start(ValueStore, [])

    # Eh.. not great. PIDs are not serializable and keeping a PID in atters seems... not good
    # (but is does allow for showcasing `to_source`)
    ctx = assign(ctx, genserver_pid: :erlang.pid_to_list(pid))

    {:ok, ctx}
  end

  @impl Kino.JS.Live
  def handle_connect(ctx) do
    # Data returned get passed to JS init function, so that we can restore the saved state in the UI
    {:ok,
     %{
       "gattServiceUUID" => ctx.assigns.gatt_service_uuid,
       "gattCharacteristicUUID" => ctx.assigns.gatt_characteristic_uuid,
       "variableName" => ctx.assigns.variable_name
     }, ctx}
  end

  @impl Kino.SmartCell
  def to_attrs(ctx) do
    # We need to be able to serialise the state of the smart cell in order to save it
    # The serialised state needs to be representable as JSON
    # The values gets saved as base64 encoded JSON in the markdown file

    %{
      "gatt_service_uuid" => ctx.assigns.gatt_service_uuid,
      "gatt_characteristic_uuid" => ctx.assigns.gatt_characteristic_uuid,
      "variable_name" => ctx.assigns.variable_name,
      "genserver_pid" => ctx.assigns.genserver_pid
    }
  end

  @impl Kino.SmartCell
  def to_source(attrs) do
    # Called when attrs change
    quote do
      unquote(quoted_var(attrs["variable_name"])) =
        unquote(attrs["genserver_pid"]) |> :erlang.list_to_pid()
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

  @impl Kino.JS.Live
  def handle_event("update_gatt_characteristic", gatt_characteristic_uuid, ctx) do
    {:noreply, assign(ctx, gatt_characteristic_uuid: gatt_characteristic_uuid)}
  end

  @impl Kino.JS.Live
  def handle_event("update_variable_name", variable_name, ctx) do
    {:noreply, assign(ctx, variable_name: variable_name)}
  end

  @impl Kino.JS.Live
  def handle_event("value_update", update, ctx) do
    # Drop a few bytes off the front
    [_length, _hub_id, _message_type, _port | rest] = Map.values(update)

    # pid = :erlang.list_to_pid(ctx.assigns.genserver_pid)
    # ValueStore.push_value(pid, rest)

    {:noreply, ctx}
  end
end
