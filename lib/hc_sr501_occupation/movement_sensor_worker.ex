defmodule HcSr501Occupation.MovementSensorWorker do
  use GenServer
  alias Circuits.GPIO

  @enforce_keys [:topic, :pin, :pin_ref]
  defstruct [:topic, :pin, :pin_ref, :last_movement]

  @type t :: %__MODULE__{
          topic: atom(),
          pin: pos_integer(),
          pin_ref: reference(),
          last_movement: DateTime.t()
        }

  @doc "GPIO Pin to which the sensor is attached"
  @callback pin :: pos_integer()

  def start_link({topic, pin, name}) do
    GenServer.start_link(__MODULE__, {topic, pin}, name: name)
  end

  @impl GenServer
  def init({topic, pin}) do
    {:ok, pin_ref} = GPIO.open(pin, :input)
    :ok = GPIO.set_pull_mode(pin_ref, :pulldown)
    :ok = GPIO.set_interrupts(pin_ref, :both)
    {:ok, %__MODULE__{topic: topic, pin: pin, pin_ref: pin_ref}}
  end

  @impl GenServer
  def handle_call(:subscription, {caller, _}, %{topic: topic, last_movement: last_movement} = s) do
    unless is_nil(last_movement), do: send(caller, {topic, :movement_detected, last_movement})
    {:reply, :ok, s}
  end

  @impl GenServer
  def handle_info({:circuits_gpio, pin, _, 1}, %{topic: topic, pin: pin} = s) do
    now = DateTime.utc_now()
    SimplestPubSub.publish(topic, {topic, :movement_detected, now})
    {:noreply, %{s | last_movement: now}}
  end

  def handle_info({:circuits_gpio, pin, _, 0}, %{topic: topic, pin: pin} = s) do
    SimplestPubSub.publish(topic, {topic, :movement_stopped, DateTime.utc_now()})
    {:noreply, s}
  end
end
