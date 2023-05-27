defmodule HcSr501Occupation.MovementSensorTest do
  use ExUnit.Case
  alias Circuits.GPIO
  alias HcSr501Occupation.MovementSensor

  defmodule Sensor do
    use MovementSensor

    @impl MovementSensor
    def pin, do: 1

    @impl MovementSensor
    def occupation_timeout, do: 50
  end

  defmodule SensorWithLongOccupationTimeout do
    use MovementSensor

    @impl MovementSensor
    def pin, do: 3

    @impl MovementSensor
    def occupation_timeout, do: :timer.seconds(180)
  end

  # See circuits GPIO doc for use of even numbered pins to change state of odd numbered pins
  # when running on the host https://hexdocs.pm/circuits_gpio/readme.html#testing
  setup do
    assert %{name: :stub} = GPIO.info()
    {:ok, control_pin} = GPIO.open(0, :output)
    GPIO.write(control_pin, 0)

    {:ok, long_control_pin} = GPIO.open(2, :output)
    GPIO.write(long_control_pin, 0)

    ensure_previous_shutdown()
    {:ok, _pid} = Sensor.start_link({})
    {:ok, _pid} = SensorWithLongOccupationTimeout.start_link({})
    {:ok, control_pin: control_pin, long_control_pin: long_control_pin}
  end

  defp ensure_previous_shutdown(count \\ 0)
  defp ensure_previous_shutdown(100), do: flunk("Previous supervisor(s) still around")

  defp ensure_previous_shutdown(count) do
    if sensor_registered?(SensorWithLongOccupationTimeout) || sensor_registered?(Sensor) do
      Process.sleep(1)
      ensure_previous_shutdown(count + 1)
    end
  end

  defp sensor_registered?(name) do
    "#{name}.Supervisor" |> String.to_atom() |> Process.whereis()
  end

  describe "movement notification" do
    setup do
      Sensor.subscribe()
      :ok
    end

    test "notification received when movement is detected", %{control_pin: control_pin} do
      GPIO.write(control_pin, 1)
      assert_receive {Sensor, :movement_detected, %DateTime{} = _timestamp}
    end

    test "notification received when movement stops", %{control_pin: control_pin} do
      GPIO.write(control_pin, 1)
      GPIO.write(control_pin, 0)
      assert_receive {Sensor, :movement_stopped, %DateTime{} = _timestamp}
    end
  end

  test "on subscribing a process will received the last movement detection", %{
    control_pin: control_pin
  } do
    GPIO.write(control_pin, 1)
    Sensor.subscribe()
    assert_receive {Sensor, :movement_detected, %DateTime{}}
  end

  test "on subscribing a process will not receive a movement detection if none has been detected" do
    Sensor.subscribe()
    refute_receive {Sensor, :movement_detected, _}
  end

  test "on subscribing a process will receive the last movement detection, not the last movement stopped",
       %{control_pin: control_pin} do
    GPIO.write(control_pin, 1)
    GPIO.write(control_pin, 0)
    Sensor.subscribe()
    assert_receive {Sensor, :movement_detected, %DateTime{}}
  end

  describe "occupation status" do
    setup do
      Sensor.subscribe()
      SensorWithLongOccupationTimeout.subscribe()
      :ok
    end

    test "is initially unoccupied" do
      assert_receive {Sensor, :unoccupied, %DateTime{} = _timestamp}
      assert_receive {SensorWithLongOccupationTimeout, :unoccupied, %DateTime{} = _timestamp}
      refute_receive {Sensor, _}
      refute_receive {SensorWithLongOccupationTimeout, _}
    end

    test "becomes occupied as soon as movement is detected", %{
      control_pin: control_pin,
      long_control_pin: long_control_pin
    } do
      GPIO.write(control_pin, 1)
      assert_receive {Sensor, :occupied, %DateTime{} = _timestamp}

      GPIO.write(long_control_pin, 1)
      assert_receive {SensorWithLongOccupationTimeout, :occupied, %DateTime{} = _timestamp}

      assert {true, _} = SensorWithLongOccupationTimeout.occupation()
    end

    test "when occupied does not become unoccupied until the occupation timeout", %{
      long_control_pin: control_pin
    } do
      flush_message_queue()
      GPIO.write(control_pin, 1)
      assert_receive {SensorWithLongOccupationTimeout, :occupied, _}
      GPIO.write(control_pin, 0)
      refute_receive {SensorWithLongOccupationTimeout, :unoccupied, _}
      assert {true, _} = SensorWithLongOccupationTimeout.occupation()
    end

    test "becomes unoccupied when the occupation timeout is reached", %{
      control_pin: control_pin
    } do
      flush_message_queue()
      GPIO.write(control_pin, 1)
      assert_receive {Sensor, :occupied, _}
      GPIO.write(control_pin, 0)
      assert_receive {Sensor, :unoccupied, _}
      assert {false, _} = Sensor.occupation()
    end

    test "detecting movement again prevents an unoccupied message", %{control_pin: control_pin} do
      flush_message_queue()
      GPIO.write(control_pin, 1)
      GPIO.write(control_pin, 0)
      GPIO.write(control_pin, 1)

      refute_receive {Sensor, :unoccupied, _}
    end

    test "multiple occupation events can occur without incident", %{control_pin: control_pin} do
      flush_message_queue()

      for _ <- 1..2 do
        # To occupied
        GPIO.write(control_pin, 1)
        assert_receive {Sensor, :occupied, _}

        # Movement stopped but detected again before becoming unoccupied
        GPIO.write(control_pin, 0)
        GPIO.write(control_pin, 1)
        refute_receive {Sensor, :unoccupied, _}

        # Become unoccupied
        GPIO.write(control_pin, 0)
        assert_receive {Sensor, :unoccupied, _}
      end
    end

    test "occupation status can be set" do
      Sensor.set_occupied(true, ~U[2023-11-03 11:12:13Z])
      assert_receive {Sensor, :occupied, ~U[2023-11-03 11:12:13Z]}

      assert {true, ~U[2023-11-03 11:12:13Z]} = Sensor.occupation()

      Sensor.set_occupied(false, ~U[2023-11-04 11:12:13Z])
      assert_receive {Sensor, :unoccupied, ~U[2023-11-04 11:12:13Z]}

      {false, ~U[2023-11-04 11:12:13Z]} = Sensor.occupation()
    end
  end

  defp flush_message_queue do
    receive do
      _ -> flush_message_queue()
    after
      1 -> :ok
    end
  end
end
