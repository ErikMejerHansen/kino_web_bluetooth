defmodule KinoWebBluetooth.Characteristic do
  @moduledoc """
  A GATT characteristic of a connected device.

  The struct is a lightweight handle, used with the functions in
  `KinoWebBluetooth`. Behind every handle runs a `GenServer`, started
  when the device connects and stopped when it disconnects. The server
  owns the characteristic state (last value, subscribers) and runs GATT
  operations one at a time, as browsers reject concurrent operations on
  the same characteristic.
  """

  use GenServer, restart: :temporary

  require Logger

  @enforce_keys [:device_id, :service, :uuid]
  defstruct [:device_id, :service, :uuid, properties: []]

  @type property ::
          :broadcast
          | :read
          | :write_without_response
          | :write
          | :notify
          | :indicate
          | :authenticated_signed_writes
          | :reliable_write
          | :writable_auxiliaries

  @type t :: %__MODULE__{
          device_id: String.t(),
          service: String.t(),
          uuid: String.t(),
          properties: [property()]
        }

  @properties [
    :broadcast,
    :read,
    :write_without_response,
    :write,
    :notify,
    :indicate,
    :authenticated_signed_writes,
    :reliable_write,
    :writable_auxiliaries
  ]

  @default_timeout 5_000

  @doc false
  def properties, do: @properties

  ## Client (used by KinoWebBluetooth and the Smart Cell)

  @doc false
  def start_link(opts) do
    char = Keyword.fetch!(opts, :characteristic)
    GenServer.start_link(__MODULE__, opts, name: via(char))
  end

  @doc false
  def whereis(%__MODULE__{} = char), do: lookup(char.device_id, char.service, char.uuid)

  @doc false
  def read(char, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    call(char, {:read, timeout}, timeout)
  end

  @doc false
  def write(char, value, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    call(char, {:write, IO.iodata_to_binary(value), opts[:with_response], timeout}, timeout)
  end

  @doc false
  def write_async(char, value, opts \\ []) do
    cast(char, {:write, IO.iodata_to_binary(value), opts[:with_response]})
  end

  @doc false
  def subscribe(char, pid, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    call(char, {:subscribe, pid, timeout}, timeout)
  end

  @doc false
  def unsubscribe(char, pid), do: call(char, {:unsubscribe, pid}, @default_timeout)

  @doc false
  def ui_read(char), do: cast(char, :ui_read)

  @doc false
  def ui_write(char, value), do: cast(char, {:write, value, nil})

  @doc false
  def ui_subscribe(char, enabled?), do: cast(char, {:ui_subscribe, enabled?})

  @doc false
  # Delivers a browser response or notification to the characteristic server.
  def deliver(device_id, service, uuid, message) do
    if pid = lookup(device_id, service, uuid), do: GenServer.cast(pid, message)
    :ok
  end

  defp call(char, message, timeout) do
    case whereis(char) do
      nil ->
        {:error, :not_connected}

      pid ->
        try do
          # Leave room for the server side timeout to reply first
          GenServer.call(pid, message, timeout + 1_000)
        catch
          :exit, {:timeout, _} -> {:error, :timeout}
          :exit, _ -> {:error, :disconnected}
        end
    end
  end

  defp cast(char, message) do
    case whereis(char) do
      nil -> {:error, :not_connected}
      pid -> GenServer.cast(pid, message)
    end
  end

  defp via(char) do
    {:via, Registry, {KinoWebBluetooth.Registry, key(char.device_id, char.service, char.uuid)}}
  end

  defp lookup(device_id, service, uuid) do
    case Registry.lookup(KinoWebBluetooth.Registry, key(device_id, service, uuid)) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  defp key(device_id, service, uuid), do: {:characteristic, device_id, service, uuid}

  ## Server

  @impl true
  def init(opts) do
    device = Keyword.fetch!(opts, :device)

    {:ok,
     %{
       device_ref: Process.monitor(device),
       char: Keyword.fetch!(opts, :characteristic),
       bridge: Keyword.fetch!(opts, :bridge),
       value: nil,
       error: nil,
       queue: :queue.new(),
       in_flight: nil,
       subscribers: %{},
       ui_subscribed: false,
       notifying: false
     }}
  end

  @impl true
  def handle_call({:read, timeout}, from, state) do
    if readable?(state.char) do
      {:noreply, enqueue(state, %{op: :read, from: from, timeout: timeout})}
    else
      {:reply, {:error, :not_readable}, state}
    end
  end

  def handle_call({:write, value, with_response, timeout}, from, state) do
    case write_op(state.char, with_response) do
      {:ok, op} ->
        {:noreply, enqueue(state, %{op: op, value: value, from: from, timeout: timeout})}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:subscribe, pid, timeout}, from, state) do
    if notifiable?(state.char) do
      state = add_subscriber(state, pid)
      {:noreply, sync_notifications(state, from, pid, timeout)}
    else
      {:reply, {:error, :not_notifiable}, state}
    end
  end

  def handle_call({:unsubscribe, pid}, _from, state) do
    state = remove_subscriber(state, pid)
    {:reply, :ok, sync_notifications(state, nil, nil, @default_timeout)}
  end

  @impl true
  def handle_cast({:write, value, with_response}, state) do
    case write_op(state.char, with_response) do
      {:ok, op} ->
        {:noreply, enqueue(state, %{op: op, value: value, timeout: @default_timeout})}

      {:error, reason} ->
        log_failure(state, :write, reason)
        {:noreply, changed(%{state | error: format_error(reason)})}
    end
  end

  def handle_cast(:ui_read, state) do
    if readable?(state.char) do
      {:noreply, enqueue(state, %{op: :read, timeout: @default_timeout})}
    else
      {:noreply, changed(%{state | error: format_error(:not_readable)})}
    end
  end

  def handle_cast({:ui_subscribe, enabled?}, state) do
    state = changed(%{state | ui_subscribed: enabled? and notifiable?(state.char)})
    {:noreply, sync_notifications(state, nil, :ui, @default_timeout)}
  end

  def handle_cast({:response, ref, result}, %{in_flight: %{ref: ref} = request} = state) do
    Process.cancel_timer(request.timer)
    {:noreply, %{state | in_flight: nil} |> complete(request, result) |> dispatch()}
  end

  def handle_cast({:response, _stale_ref, _result}, state), do: {:noreply, state}

  def handle_cast({:notification, value}, state) do
    for {pid, _ref} <- state.subscribers do
      send(pid, {:kino_web_bluetooth, :notification, state.char, value})
    end

    {:noreply, changed(%{state | value: value})}
  end

  @impl true
  def handle_info({:request_timeout, ref}, %{in_flight: %{ref: ref} = request} = state) do
    {:noreply, %{state | in_flight: nil} |> complete(request, {:error, :timeout}) |> dispatch()}
  end

  def handle_info({:request_timeout, _stale_ref}, state), do: {:noreply, state}

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{device_ref: ref} = state) do
    {:stop, :normal, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    state = remove_subscriber(state, pid)
    {:noreply, sync_notifications(state, nil, nil, @default_timeout)}
  end

  @impl true
  def terminate(_reason, state) do
    pending = if state.in_flight, do: [state.in_flight], else: []

    for %{from: from} <- pending ++ :queue.to_list(state.queue) do
      reply(from, {:error, :disconnected})
    end

    for {pid, _ref} <- state.subscribers do
      send(pid, {:kino_web_bluetooth, :disconnected, state.char})
    end

    :ok
  end

  ## Request queue

  defp enqueue(state, request) do
    request = Map.merge(%{from: nil, value: nil, subscriber: nil}, request)
    dispatch(%{state | queue: :queue.in(request, state.queue)})
  end

  defp dispatch(%{in_flight: nil} = state) do
    case :queue.out(state.queue) do
      {{:value, request}, queue} ->
        ref = System.unique_integer([:positive])
        timer = Process.send_after(self(), {:request_timeout, ref}, request.timeout)

        send(state.bridge, {
          :kino_web_bluetooth,
          :request,
          %{
            ref: ref,
            op: request.op,
            service: state.char.service,
            characteristic: state.char.uuid,
            value: request.value
          }
        })

        %{state | queue: queue, in_flight: Map.merge(request, %{ref: ref, timer: timer})}

      {:empty, _queue} ->
        state
    end
  end

  defp dispatch(state), do: state

  defp complete(state, %{op: :read} = request, {:ok, value}) do
    reply(request.from, {:ok, value})
    changed(%{state | value: value, error: nil})
  end

  defp complete(state, %{op: op} = request, {:ok, _}) do
    reply(request.from, :ok)

    state =
      case op do
        :start_notifications -> changed(%{state | notifying: true, error: nil})
        :stop_notifications -> changed(%{state | notifying: false, error: nil})
        _write -> clear_error(state)
      end

    sync_notifications(state, nil, nil, @default_timeout)
  end

  defp complete(state, request, {:error, reason}) do
    reply(request.from, {:error, reason})

    if request.from == nil, do: log_failure(state, request.op, reason)

    state =
      case request.subscriber do
        nil -> state
        :ui -> %{state | ui_subscribed: false}
        pid -> remove_subscriber(state, pid)
      end

    changed(%{state | error: format_error(reason)})
  end

  ## Notifications

  defp add_subscriber(state, pid) do
    if Map.has_key?(state.subscribers, pid) do
      state
    else
      put_in(state.subscribers[pid], Process.monitor(pid))
    end
  end

  defp remove_subscriber(state, pid) do
    {ref, subscribers} = Map.pop(state.subscribers, pid)
    if ref, do: Process.demonitor(ref, [:flush])
    %{state | subscribers: subscribers}
  end

  # Starts or stops browser notifications so they match the wanted state.
  defp sync_notifications(state, from, subscriber, timeout) do
    wanted? = state.ui_subscribed or map_size(state.subscribers) > 0

    cond do
      wanted? and not state.notifying ->
        enqueue(state, %{
          op: :start_notifications,
          from: from,
          subscriber: subscriber,
          timeout: timeout
        })

      not wanted? and state.notifying and not stop_pending?(state) ->
        reply(from, :ok)
        enqueue(state, %{op: :stop_notifications, timeout: timeout})

      true ->
        reply(from, :ok)
        state
    end
  end

  defp stop_pending?(state) do
    Enum.any?(
      [state.in_flight | :queue.to_list(state.queue)],
      &match?(%{op: :stop_notifications}, &1)
    )
  end

  ## Helpers

  defp readable?(char), do: :read in char.properties

  defp notifiable?(char), do: :notify in char.properties or :indicate in char.properties

  defp write_op(char, with_response) do
    with_response = if with_response == nil, do: :write in char.properties, else: with_response

    cond do
      with_response and :write in char.properties ->
        {:ok, :write}

      not with_response and :write_without_response in char.properties ->
        {:ok, :write_without_response}

      true ->
        {:error, :not_writable}
    end
  end

  defp log_failure(state, op, reason) do
    Logger.warning(
      "[KinoWebBluetooth] #{op} on #{state.char.uuid} failed: #{format_error(reason)}"
    )
  end

  defp reply(nil, _message), do: :ok
  defp reply(from, message), do: GenServer.reply(from, message)

  defp clear_error(%{error: nil} = state), do: state
  defp clear_error(state), do: changed(%{state | error: nil})

  defp changed(state) do
    send(state.bridge, {
      :kino_web_bluetooth,
      :characteristic_changed,
      Map.take(state, [:char, :value, :error, :notifying, :ui_subscribed])
    })

    state
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: reason |> to_string() |> String.replace("_", " ")
end
