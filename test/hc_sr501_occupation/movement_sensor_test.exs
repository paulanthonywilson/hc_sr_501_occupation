defmodule HcSr501Occupation.MovementSensorTest do
  use ExUnit.Case
  alias Circuits.GPIO
  alias HcSr501Occupation.MovementSensor

  defmodule SensorUT do
    use MovementSensor

    @impl MovementSensor
    def pin, do: 1
  end

  # See circuits GPIO doc for use of even numbered pins to change state of odd numbered pins
  # when running on the host https://hexdocs.pm/circuits_gpio/readme.html#testing
  setup do
    assert %{name: :stub} = GPIO.info()
    {:ok, control_pin} = GPIO.open(0, :output)
    GPIO.write(control_pin, 0)

    {:ok, _pid} = SensorUT.start_link({})
    {:ok, control_pin: control_pin}
  end

  describe "subscriber notification" do
    setup do
      SensorUT.subscribe()
      :ok
    end

    test "notification received when movement is detected", %{control_pin: control_pin} do
      GPIO.write(control_pin, 1)
      assert_receive {SensorUT, :movement_detected, %DateTime{} = _timestamp}
    end

    test "notification received when movement stops", %{control_pin: control_pin} do
      GPIO.write(control_pin, 1)
      GPIO.write(control_pin, 0)
      assert_receive {SensorUT, :movement_stopped, %DateTime{} = _timestamp}
    end
  end

  test "on subscribing a process will received the last movement detection", %{
    control_pin: control_pin
  } do
    GPIO.write(control_pin, 1)
    flush_sensor_message_queue()
    SensorUT.subscribe()
    assert_receive {SensorUT, :movement_detected, %DateTime{}}
  end

  test "on subscribing a process will not receive a movement detection if none has been detected" do
    flush_sensor_message_queue()
    SensorUT.subscribe()
    refute_receive {SensorUT, :movement_detected, _}
  end

  defp flush_sensor_message_queue do
    :sys.get_state(SensorUT)
  end
end
