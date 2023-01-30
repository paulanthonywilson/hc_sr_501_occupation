defmodule HcSr501Occupation.MovementSensor do
  @moduledoc """
  Instanace of the Movement Sensor
  """

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      def start_link(_) do
        HcSr501Occupation.MovementSensorSupervisor.start_link({__MODULE__, pin()})
      end

      def subscribe do
        HcSr501Occupation.MovementSensorSupervisor.subscribe(__MODULE__)
      end
    end
  end

  @doc "GPIO Pin to which the sensor is attached"
  @callback pin :: pos_integer()
end
