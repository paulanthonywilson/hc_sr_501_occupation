defmodule HcSr501Occupation.MovementSensor do
  @moduledoc """
  Instanance of the movement and occupation sensor.
  """

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      def start_link(_) do
        HcSr501Occupation.MovementSensorSupervisor.start_link(
          {__MODULE__, pin(), occupation_timeout()}
        )
      end

      def subscribe do
        HcSr501Occupation.MovementSensorSupervisor.subscribe(__MODULE__)
      end

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor,
          restart: :permanent,
          shutdown: 500
        }
      end
    end
  end

  @doc "GPIO Pin to which the sensor is attached"
  @callback pin :: pos_integer()

  @doc """
  In milliseconds, how long after movement is no longer detected do we flip the state to unnocupied
  """
  @callback occupation_timeout :: pos_integer()
end
