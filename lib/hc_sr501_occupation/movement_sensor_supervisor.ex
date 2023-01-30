defmodule HcSr501Occupation.MovementSensorSupervisor do
  use Supervisor

  def start_link({name, _pin} = args) do
    supervisor_name = String.to_atom("#{name}.Supervisor")
    Supervisor.start_link(__MODULE__, args, name: supervisor_name)
  end

  def init({name, pin}) do
    children = [
      {HcSr501Occupation.MovementSensorWorker, {name, pin, sensor_name(name)}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def subscribe(name) do
    GenServer.call(sensor_name(name), :subscription)
    SimplestPubSub.subscribe(name)
  end

  defp sensor_name(name), do: String.to_atom("#{name}.Sensor")
end
