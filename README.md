# HcSr501 Occupation

[Nerves](https://nerves-project.org), or similar, Elixir library for interfacing with a [HC-SR501](https://duckduckgo.com/?q=HC-SR501) passive infra-red motion sensor. 

It broadcasts to subscribing processes when movement is detected, no longer detected. Additionally it will broadcast when its operational area has not seen movement in long enough period for it to decide that the area has become occupied.  Similarly it will broadcast when an area deemed unoccupied becomes occupied.


## Installation

```elixir
def deps do
  [
    {:hc_sr_501_occupation, "~> 0.1.0"}
  ]
end

```
## Usage

Define the sensor in your project.

An example is below: the HC-SR501 out pin is attached to GPIO pin 17; we deem the area monitored to be unoccupied after 3 minutes of no movement detection.


```elixir
defmodule Movement.Sensor do
  use HcSr501Occupation.MovementSensor

  @impl HcSr501Occupation.MovementSensor
  def pin, do: 17

  @impl HcSr501Occupation.MovementSensor
  def occupation_timeout, do: :timer.seconds(180)
end
```

In your application (or other supervisor) include your module as a child:

```elixir
defmodule Movement.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Movement.Sensor
    ]

    opts = [strategy: :one_for_one, name: Movement.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Note that the module's `pin/0` and `occoupation_timeout/0` are read at start; modifying the values after that point will have no impact without going in and killing processes.

A processes can subscribe to receive a message when a movement event has occurred, with the `subscribe/0` function that has been added to your module, eg

```elixir
MovementSensor.subscribe()
```

On subscription your process will receive an occupation message with its current state. If movement has been detected since startup, then the last movement detection will also be sent.

Subsequent occupation and movement detection messages will also be sent to subscribed processes. Each message is a tuple, the first element of which is the name of your module - in our example `Movement.Sensor`

The following messages can be received:

### Movement detected

The HC-SR501 has detected movement and will send a message like

```elixir
{Movement.Sensor, :movement_detected, ~U[2023-02-01 12:34:40.883973Z]}
```

The last element is the `DateTime` at which movement was detected.

### Movement stopped

When the HC-SR501 stops detecting movement the following type of message will be sent to subscribers.


```elixir
{Movement.Sensor, :movement_stopped, ~U[2023-02-01 12:34:40.883973Z]}
```

The last element is the `DateTime` at which the movement stopped signal was received.


### Occupied

When we determine that a previously unoccupied are has become occupied, by detecting any movement, then the following form of message will be sent to subscribers


```elixir
{Movement.Sensor, :occupied, ~U[2023-02-01 12:34:40.883973Z]}
```

By its nature this will always be preceeded by a `:movement_detected` message, with the same timestamp as in this message.

### Unoccupied

An area is deemed unoccupied either at startup (of the process monitoring for occupation) or after no movement has been detected for the configured time when the area is deemed to have previously been occupied.

When we determine that an area is unoccupied then subscribers will receive messages of the form

```elixir
{Movement.Sensor, :unoccupied, ~U[2023-02-01 12:34:40.883973Z]}
```

The `DateTime` in a message received when starting up will be the startup time. The `DateTime` in a message caused by an occupied area being deemed to have become unoccupied, will be the time at which the last `:unoccupied` message was received.