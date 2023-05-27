defmodule HcSr501Occupation.MovementSensor do
  @moduledoc """
  Creates an instance of the movement and occupation sensor.

  Usage:

  ```
  defmodule MyApp.MySensor do
    use HcSr501Occupation.MovementSensor

    @impl HcSr501Occupation.MovementSensor
    def pin, do: 17

    @impl HcSr501Occupation.MovementSensor
    def occupation_timeout, do: :timer.seconds(180)
  end
  ```

  Add to the supervision tree, eg
  ```
  defmodule MyApp.Application do
    use Application

    def start(_type, _args) do
      children = [
        MyApp.MySensor
      ]
      opts = [strategy: :one_for_one, name: MyApp.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end
  ```

  See README for full usage.
  """

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)

      def start_link(_) do
        HcSr501Occupation.MovementSensorSupervisor.start_link(
          {__MODULE__, pin(), occupation_timeout()}
        )
      end

      def subscribe do
        HcSr501Occupation.MovementSensorSupervisor.subscribe(__MODULE__)
      end

      def set_occupied(occupied?, %DateTime{} = timestamp) when is_boolean(occupied?) do
        HcSr501Occupation.MovementSensorSupervisor.set_occupied(__MODULE__, occupied?, timestamp)
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
  In milliseconds, how long after movement is no longer detected do we flip the state to unoccupied
  """
  @callback occupation_timeout :: pos_integer()

  @doc """
  Automatically implemented by the `__using__` macro.

  Sets the occupation status. Provided for setting on reboot if the client has persisted the status
  somewhere. The status will be broadcast to all subscribers
  """
  @callback set_occupied(occupied? :: boolean(), timestamp :: DateTime.t()) :: :ok
end
