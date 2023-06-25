defmodule HcSr501Occupation.OccupationWorkerTest do
  use ExUnit.Case, async: false
  alias HcSr501Occupation.OccupationWorker

  # See `HcSr501Occupation.MovementSensorTest` for most beheaviour definitions

  @a_date_time ~U[2023-02-01 11:12:13Z]

  setup do
    name = self() |> inspect() |> String.to_atom()
    {:ok, pid} = OccupationWorker.start_link({:occupation_topic, 10, name})
    :ok = SimplestPubSub.subscribe(:occupation_topic)
    {:ok, pid: pid}
  end

  test "occupation timestamp is based on movement detected timestamp" do
    timestamp = ~U[2011-01-12 15:37:21Z]
    SimplestPubSub.publish(:occupation_topic, {:occupation_topic, :movement_detected, timestamp})
    assert_receive {:occupation_topic, :occupied, ^timestamp}
  end

  test "multiple movement detection does not result in multiple occupation events" do
    SimplestPubSub.publish(
      :occupation_topic,
      {:occupation_topic, :movement_detected, DateTime.utc_now()}
    )

    SimplestPubSub.publish(
      :occupation_topic,
      {:occupation_topic, :movement_detected, DateTime.utc_now()}
    )

    assert_receive {:occupation_topic, :occupied, _}
    refute_receive {:occupation_topic, :occupied, _}
  end

  test "unoccupied timestamp is that of when movement was last detected" do
    SimplestPubSub.publish(
      :occupation_topic,
      {:occupation_topic, :movement_detected, DateTime.utc_now()}
    )

    stopped_timestamp = ~U[2015-11-03 12:10:01Z]

    SimplestPubSub.publish(
      :occupation_topic,
      {:occupation_topic, :movement_stopped, stopped_timestamp}
    )

    assert_receive {:occupation_topic, :unoccupied, ^stopped_timestamp}
  end

  test "occupation timeout cancelled when movement detected", %{pid: pid} do
    SimplestPubSub.publish(
      :occupation_topic,
      {:occupation_topic, :movement_detected, DateTime.utc_now()}
    )

    SimplestPubSub.publish(
      :occupation_topic,
      {:occupation_topic, :movement_stopped, DateTime.utc_now()}
    )

    %{occupation_timer: timer_ref} = :sys.get_state(pid)

    assert is_integer(Process.read_timer(timer_ref))

    SimplestPubSub.publish(
      :occupation_topic,
      {:occupation_topic, :movement_detected, DateTime.utc_now()}
    )

    :sys.get_state(pid)

    refute Process.read_timer(timer_ref)
  end

  describe "explicitly setting occupation state with cast" do
    test "occupation state is set", %{pid: pid} do
      :sys.replace_state(pid, fn s -> %{s | occupation_timeout: 1_000} end)
      timestamp = ~U[2023-07-02 01:02:03Z]
      GenServer.cast(pid, {:set_occupied, true, timestamp})

      assert_receive {:occupation_topic, :occupied, ^timestamp}

      GenServer.cast(pid, {:set_occupied, false, timestamp})

      assert_receive {:occupation_topic, :unoccupied, ^timestamp}
    end

    test "when occupied, occupation timer is started with the occupation time", %{pid: pid} do
      timestamp = ~U[2023-07-02 01:02:03Z]
      GenServer.cast(pid, {:set_occupied, true, timestamp})
      %{occupation_timer: timer_ref} = :sys.get_state(pid)

      assert is_integer(Process.read_timer(timer_ref))
      assert_receive {:occupation_topic, :occupied, ^timestamp}
      assert_receive {:occupation_topic, :unoccupied, ^timestamp}
    end

    test "when unoccupied, occupation timer is not started", %{pid: pid} do
      timestamp = ~U[2023-07-02 01:02:03Z]
      GenServer.cast(pid, {:set_occupied, false, timestamp})
      assert_receive {:occupation_topic, :unoccupied, ^timestamp}
      assert %{occupation_timer: nil} = :sys.get_state(pid)

      refute_receive {:occupation_topic, :unoccupied, _}
    end
  end

  test "movement stop when unoccupied is ignored" do
    SimplestPubSub.publish(
      :occupation_topic,
      {:occupation_topic, :movement_stopped, @a_date_time}
    )

    refute_receive {:occupation_topic, :unoccupied, _}
  end
end
