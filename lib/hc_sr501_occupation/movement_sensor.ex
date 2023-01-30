defmodule HcSr501Occupation.MovementSensor do
  @moduledoc """
  Instanace of the Movement Sensor
  """
  use GenServer

  alias Circuits.GPIO

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      def start_link(_) do
        unquote(__MODULE__).start_link(__MODULE__, pin())
      end

      def subscribe do
        SimplestPubSub.subscribe(__MODULE__)
        GenServer.call(__MODULE__, :subscription)
      end
    end
  end

  defstruct [:name, :pin, :pin_ref, :last_movement]

  @type t :: %__MODULE__{
          name: atom(),
          pin: pos_integer(),
          pin_ref: reference(),
          last_movement: DateTime.t()
        }

  @doc "GPIO Pin to which the sensor is attached"
  @callback pin :: pos_integer()

  def start_link(name, pin) do
    GenServer.start_link(__MODULE__, {name, pin}, name: name)
  end

  @impl GenServer
  def init({name, pin}) do
    {:ok, pin_ref} = GPIO.open(pin, :input)
    :ok = GPIO.set_pull_mode(pin_ref, :pulldown)
    :ok = GPIO.set_interrupts(pin_ref, :both)
    {:ok, %__MODULE__{name: name, pin: pin, pin_ref: pin_ref}}
  end

  @impl GenServer
  def handle_call(:subscription, {caller, _}, %{name: name, last_movement: last_movement} = s) do
    unless is_nil(last_movement), do: send(caller, {name, :movement_detected, last_movement})
    {:reply, :ok, s}
  end

  @impl GenServer
  def handle_info({:circuits_gpio, pin, _, 1}, %{name: name, pin: pin} = s) do
    now = DateTime.utc_now()
    SimplestPubSub.publish(name, {name, :movement_detected, now})
    {:noreply, %{s | last_movement: now}}
  end

  def handle_info({:circuits_gpio, pin, _, 0}, %{name: name, pin: pin} = s) do
    SimplestPubSub.publish(name, {name, :movement_stopped, DateTime.utc_now()})
    {:noreply, s}
  end
end
