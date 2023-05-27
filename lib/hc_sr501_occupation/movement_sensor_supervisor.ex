defmodule HcSr501Occupation.MovementSensorSupervisor do
  @moduledoc false

  _doc = """
  Sets up a GenServer monitoring a GPIO pin for movement detection signals via a HC-SR501 , and broadcasting
  via the common `SimplestPubSub` topic. Also sets up a GenSever that receives the movement detection messages
  and determines whether the physical area monitored has become unoccupied, by the absence of movement over a time period, or
  occupied by noticing movement when unoccupied which also broadcasts on the same channel.

  See the README for full behaviour and message details.

  """

  use Supervisor

  @doc """
  Within the tuple
  * name (1st elem): base name to be used to register in the global process registry and `SimplestPubSub` topic. If `MyApp.Movement` then
    * this supervisor will be named `MyApp.Movement.Supervisor`
    * the movemenent detection worker will be named `MyApp.Movement.Sensor`
    * the occupation determining worker will be named `MyApp.Movement.Occupation`
  * pin (2nd elem): the GPIO pin to which the HC-SR501 data pin is connected
  * occupation_timeout (3rd elem): how long in milliseconds to wait since movement detection has stopped until we decide that the area monitored is unoccupied.
  """
  @spec start_link({name :: atom, pin :: pos_integer(), occupation_timeout :: non_neg_integer()}) ::
          {:ok, pid()} | {:error, term()}
  def start_link({name, _pin, _occupation_timeout} = args) do
    supervisor_name = String.to_atom("#{name}.Supervisor")
    Supervisor.start_link(__MODULE__, args, name: supervisor_name)
  end

  @impl Supervisor
  def init({name, pin, occupation_timeout}) do
    children = [
      {HcSr501Occupation.MovementSensorWorker, {name, pin, sensor_name(name)}},
      {HcSr501Occupation.OccupationWorker,
       {name, occupation_timeout, occupation_monitor_name(name)}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Subscribes the current process to the `SimplestPubSub` topic to receive movement detection and occupation messages. On
  the last movement detection (if any) and occupation messages are received.
  """

  def subscribe(name) do
    GenServer.call(sensor_name(name), :subscription)
    GenServer.call(occupation_monitor_name(name), :subscription)
    SimplestPubSub.subscribe(name)
  end

  @doc """
  Sets the occupation status for the sensor
  """
  def set_occupied(name, occupation?, timestamp) do
    name
    |> occupation_monitor_name()
    |> GenServer.cast({:set_occupied, occupation?, timestamp})
  end

  defp sensor_name(name), do: String.to_atom("#{name}.Sensor")
  defp occupation_monitor_name(name), do: String.to_atom("#{name}.Occupation")
end
