defmodule KinoWebBluetooth.FakeBrowser do
  @moduledoc """
  Stands in for the Smart Cell and the browser in tests.

  Answers GATT requests with scripted responses and forwards every
  request and state change to the test process.

  Responses are given per operation, as a result (`{:ok, value}` or
  `{:error, reason}`), a function of the request, or `:no_reply`.
  Operations without a scripted response succeed.
  """

  use GenServer

  alias KinoWebBluetooth.Characteristic

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts) do
    {:ok,
     %{
       test: Keyword.fetch!(opts, :test),
       device_id: Keyword.fetch!(opts, :device_id),
       responses: Keyword.get(opts, :responses, [])
     }}
  end

  @impl true
  def handle_info({:kino_web_bluetooth, :request, %{op: :disconnect} = request}, state) do
    send(state.test, {:browser_request, request})
    {:noreply, state}
  end

  def handle_info({:kino_web_bluetooth, :request, request}, state) do
    send(state.test, {:browser_request, request})

    case Keyword.get(state.responses, request.op, {:ok, nil}) do
      :no_reply -> :ok
      fun when is_function(fun, 1) -> reply(state, request, fun.(request))
      result -> reply(state, request, result)
    end

    {:noreply, state}
  end

  def handle_info({:kino_web_bluetooth, _change, _data} = message, state) do
    send(state.test, message)
    {:noreply, state}
  end

  defp reply(state, request, result) do
    Characteristic.deliver(
      state.device_id,
      request.service,
      request.characteristic,
      {:response, request.ref, result}
    )
  end
end
