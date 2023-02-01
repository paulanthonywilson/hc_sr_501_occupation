defmodule HcSr501Occupation.OccupationWorker do
  @moduledoc """
  Monitors the movement sensor notifications, to determine occupation status of the monitored area deduced from a lack of movement

  """

  use GenServer
  defstruct [:topic, :occupied?, :occupation_timestamp, :occupation_timeout, :occupation_timer]

  @type t :: %__MODULE__{
          topic: atom(),
          occupied?: boolean(),
          occupation_timeout: pos_integer(),
          occupation_timestamp: DateTime.t(),
          occupation_timer: reference()
        }
  @spec start_link({topic :: atom, occupation_timeout :: pos_integer(), name :: atom}) ::
          :ignore | {:error, any} | {:ok, pid}
  def start_link({topic, occupation_timeout, name}) do
    GenServer.start_link(__MODULE__, {topic, occupation_timeout}, name: name)
  end

  def init({topic, occupation_timeout}) do
    SimplestPubSub.subscribe(topic)

    {:ok,
     %__MODULE__{
       topic: topic,
       occupied?: false,
       occupation_timeout: occupation_timeout,
       occupation_timestamp: DateTime.utc_now()
     }}
  end

  def handle_call(:subscription, {from, _}, s) do
    send(from, occupation_event(s))
    {:reply, :ok, s}
  end

  def handle_info(
        {topic, :movement_detected, timestamp},
        %{topic: topic, occupation_timer: occupation_timer} = s
      ) do
    if occupation_timer do
      Process.cancel_timer(occupation_timer)
    end

    {:noreply, maybe_become_occupied(s, timestamp)}
  end

  def handle_info(
        {topic, :movement_stopped, timestamp},
        %{topic: topic, occupation_timeout: occupation_timeout, occupied?: true} = s
      ) do
    timer_ref = Process.send_after(self(), {:occupation_timeout, timestamp}, occupation_timeout)

    {:noreply, %{s | occupation_timer: timer_ref}}
  end

  def handle_info({:occupation_timeout, no_movement_time}, s) do
    new_state = %{s | occupied?: false, occupation_timestamp: no_movement_time}
    publish_occupation_event(new_state)
    {:noreply, new_state}
  end

  def handle_info(_, s) do
    {:noreply, s}
  end

  defp maybe_become_occupied(%{occupied?: true} = s, _timestamp), do: s

  defp maybe_become_occupied(previous_state, timestamp) do
    publish_occupation_event(%{previous_state | occupation_timestamp: timestamp, occupied?: true})
  end

  defp publish_occupation_event(%{topic: topic} = state) do
    SimplestPubSub.publish(topic, occupation_event(state))
    state
  end

  defp occupation_event(%{
         topic: topic,
         occupied?: occupied?,
         occupation_timestamp: occupation_timestamp
       }) do
    {topic, occupied_event_type(occupied?), occupation_timestamp}
  end

  defp occupied_event_type(true), do: :occupied
  defp occupied_event_type(_), do: :unoccupied
end
