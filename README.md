# EventBus

[![Build Status](https://travis-ci.org/otobus/event_bus.svg?branch=master)](https://travis-ci.org/otobus/event_bus)

Traceable, extendable and minimalist event bus implementation for Elixir with built-in event store and event watcher based on ETS.

![Event Bus](https://cdn-images-1.medium.com/max/1600/1*0fcfAiHvNeHCRYhp-a32YA.png)

## Table of Contents

[Features](#features)

[Installation](#installation)

[Usage](#usage)

- [Register event topics in `config.exs`](#register-event-topics-in-configexs)

- [Register/unregister event topics on demand](#registerunregister-event-topics-on-demand)

- [Subscribe to the 'event bus' with a listener and list of given topics](#subscribe-to-the-event-bus-with-a-listener-and-list-of-given-topics-notification-manager-will-match-with-regex)

- [Unsubscribe from the 'event bus'](#unsubscribe-from-the-event-bus)

- [List subscribers](#list-subscribers)

- [List subscribers of a specific event](#list-subscribers-of-a-specific-event)

- [Event data structure](#event-data-structure)

- [Define an event struct](#event-data-structure)

- [Notify all subscribers with `EventBus.Model.Event` data](#notify-all-subscribers-with-eventbusmodelevent-data)

- [Fetch an event from the store](#fetch-an-event-from-the-store)

- [Mark as completed on Event Observation Manager](#mark-as-completed-on-event-observation-manager)

- [Mark as skipped on Event Observation Manager](#mark-as-skipped-on-event-observation-manager)

- [Check if a topic exists?](#check-if-a-topic-exists)

- [Use block builder to build `EventBus.Model.Event` struct](#use-block-builder-to-build-eventbusmodelevent-struct)

- [Use block notifier to notify event data to given topic](#use-block-notifier-to-notify-event-data-to-given-topic)

[Sample Listener Implementation](#sample-listener-implementation)

[Event Storage Details](#event-storage-details)

[Traceability](#traceability)

[EventBus.Metrics and UI](#eventbusmetrics-library)

[Documentation](#documentation)

[Addons](#addons)

[Wiki](https://github.com/otobus/event_bus/wiki)

[Contributing](#contributing)

[License](#license)

## Features

- Fast data writes with enabled concurrent writes to ETS.

- Fast data reads with enabled concurrent reads from ETS.

- Fast by design. Almost all implementation data accesses have O(1) complexity.

- Memory friendly. Instead of pushing event data, pushes event shadow(event id and topic) to only interested subscribers.

- Applies [queueing theory](https://www.vividcortex.com/resources/queueing-theory) to handle inputs.

- Extendable with addons.

- Tracable with optional attributes. Optional attributes compatiable with opentracing platform.

- Minimal with required attributes(Incase, you want it work minimal use 3 required attributes to deliver your events).

## Installation

The package can be installed by adding `event_bus` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:event_bus, "~> 1.3"}]
end
```

Be sure to include `event_bus` in your `mix.exs` Mixfile:

```elixir
def application do
  [
    applications: [
      # ...
      :event_bus
    ]
  ]
end
```

## Usage

##### Register event topics in `config.exs`

```elixir
config :event_bus, topics: [:message_received, :another_event_occured]
```

##### Register/unregister event topics on demand
```elixir
# register
EventBus.register_topic(:webhook_received)
> :ok

# unregister topic
# Warning: It also deletes the related topic tables!
EventBus.unregister_topic(:webhook_received)
> :ok
```

##### Subscribe to the 'event bus' with a listener and list of given topics, `Notification Manager` will match with Regex

```elixir
# to catch every event topic
EventBus.subscribe({MyEventListener, [".*"]})
> :ok

# to catch specific topics
EventBus.subscribe({MyEventListener, ["purchase_", "booking_confirmed$", "flight_passed$"]})
> :ok

# if your listener has a config
config = %{}
listener = {MyEventListener, config}
EventBus.subscribe({listener, [".*"]})
> :ok
```

##### Unsubscribe from the 'event bus'
```elixir
EventBus.unsubscribe(MyEventListener)
> :ok

# if your listener has a config
config = %{}
EventBus.unsubscribe({MyEventListener, config})
> :ok
```

##### List subscribers
```elixir
EventBus.subscribers()
> [{MyEventListener, [".*"]}, {{AnotherListener, %{}}, [".*"]}]
```

##### List subscribers of a specific event
```elixir
EventBus.subscribers(:hello_received)
> [MyEventListener, {{AnotherListener, %{}}}]
```

##### Event data structure

Data structure for `EventBus.Model.Event`

```elixir
%EventBus.Model.Event{
  id: String.t | integer(), # required
  transaction_id: String.t | integer(), # optional
  topic: atom(), # required
  data: any() # required,
  initialized_at: integer(), # optional, might be seconds, milliseconds or microseconds even nanoseconds since Elixir does not have a limit on integer size
  occurred_at: integer(), # optional, might be seconds, milliseconds or microseconds even nanoseconds since Elixir does not have a limit on integer size
  source: String.t, # optional, source of the event, who created it
  ttl: integer() # optional, might be seconds, milliseconds or microseconds even nanoseconds since Elixir does not have a limit on integer size. If `tll` field is set, it is recommended to set `occurred_at` field too.
}
```

**`transaction_id` attribute**

Firstly, `transaction_id` attribute is an optional field, if you need to store any meta identifier related to event transaction, it is the place to store. Secondly, `transaction_id` is one of the good ways to track events related to the same transaction on a chain of events. If you have time, have a look to the [story](https://hackernoon.com/trace-monitor-chain-of-microservice-logs-in-the-same-transaction-f13420f2d42c).

**`initialized_at` attribute**

Optional, but good to have field for all events to track when the event generator started to process for generating this event.

**`occurred_at` attribute**

Optional, but good to have field for all events to track when the event occurred with unixtimestamp value. The library does not automatically set this value since the value depends on the timing choice.

**`ttl` attribute**

Optional, but might to have field for all events to invalidate an event after a certain amount of time. Currently, the `event_bus` library does not do any specific thing using this field. If you need to discard an event in a certain amount of time, that field would be very useful.

Note: If you set this field, then `occurred_at` field is required.

##### Define an event struct

```elixir
alias EventBus.Model.Event
event = %Event{id: "123", transaction_id: "1",
  topic: :hello_received, data: %{message: "Hello"}}
another_event = %Event{id: "124", transaction_id: "1",
  topic: :bye_received, data: [user_id: 1, goal: "exit"]}
```
**Important Note:** It is important to have unique identifier for each event struct per topic. I recommend to use a unique id generator like `{:uuid, "~> 1.1"}`.

##### Notify all subscribers with `EventBus.Model.Event` data
```elixir
EventBus.notify(event)
> :ok
EventBus.notify(another_event)
> :ok
```

##### Fetch an event from the store
```elixir
topic = :bye_received
id = "124"
EventBus.fetch_event({topic, id})
> %EventBus.Model.Event{data: [user_id: 1, goal: "exit"], id: "124", topic: :bye_received, transaction_id: "1"}

# To fetch only the event data
EventBus.fetch_event_data({topic, id})
> [user_id: 1, goal: "exit"]
```

##### Mark as completed on Event Observation Manager
```elixir
listener = MyEventListener
# If your listener has config then pass tuple
listener = {MyEventListener, config}
EventBus.mark_as_completed({listener, :bye_received, id})
> :ok
```

##### Mark as skipped on Event Observation Manager
```elixir
listener = MyEventListener
# If your listener has config then pass tuple
listener = {MyEventListener, config}
EventBus.mark_as_skipped({listener, :bye_received, id})
> :ok
```

##### Check if a topic exists?
```elixir
EventBus.topic_exist?(:metrics_updated)
> false
```

##### Use block builder to build `EventBus.Model.Event` struct

Builder automatically sets `initialized_at` and `occurred_at` attributes
```elixir
use EventBus.EventSource

id = "some unique id"
topic = :user_created
transaction_id = "tx" # optional
ttl = 600_000 # optional
source = "my event creator" # optional

params = %{id: id, topic: topic, transaction_id: transaction_id, ttl: ttl, source: source}
EventSource.build(params) do
  # do some calc in here
  Process.sleep(1)
  # as a result return only the event data
  %{email: "jd@example.com", name: "John Doe"}
end
> %EventBus.Model.Event{data: %{email: "jd@example.com", name: "John Doe"},
 id: "some unique id", initialized_at: 1515274599140491,
 occurred_at: 1515274599141211, source: "my event creator", topic: :user_created, transaction_id: "tx", ttl: 600000}
```

It is recommended to set optional params in event_bus application config, this will allow you to auto generate majority of optional values without writing code. Here is a sample config for event_bus:

```elixir
config :event_bus,
  topics: [], # list of atoms
  ttl: 30_000_000, # integer
  time_unit: :micro_seconds, # atom
  id_generator: EventBus.Util.Base62 # module: must implement 'unique_id/0' function
```

After having such config like above, you can generate events without providing optional attributes like below:

```elixir
# Without optional params
params = %{topic: topic}
EventSource.build(params) do
  %{email: "jd@example.com", name: "John Doe"}
end
> %EventBus.Model.Event{data: %{email: "jd@example.com", name: "John Doe"},
 id: "Ewk7fL6Erv0vsW6S", initialized_at: 1515274599140491,
 occurred_at: 1515274599141211, source: "AutoModuleName", topic: :user_created,
 transaction_id: nil, ttl: 30_000_000}

# With optional error topic param
params = %{id: id, topic: topic, error_topic: :user_create_erred}
EventSource.build(params) do
  {:error, %{email: "Invalid format"}}
end
> %EventBus.Model.Event{data: {:error, %{email: "Invalid format"}},
 id: "some unique id", initialized_at: 1515274599140491,
 occurred_at: 1515274599141211, source: nil, topic: :user_create_erred,
 transaction_id: nil, ttl: 30_000_000}
```

##### Use block notifier to notify event data to given topic

Builder automatically sets `initialized_at` and `occurred_at` attributes
```elixir
use EventBus.EventSource

id = "some unique id"
topic = :user_created
error_topic = :user_create_erred # optional (incase error tuple return in yield execution, it will use :error_topic value as :topic for event creation)
transaction_id = "tx" # optional
ttl = 600_000 # optional
source = "my event creator" # optional
EventBus.register_topic(topic) # incase you didn't register it in `config.exs`

params = %{id: id, topic: topic, transaction_id: transaction_id, ttl: ttl, source: source, error_topic: error_topic}
EventSource.notify(params) do
  # do some calc in here
  # as a result return only the event data
  %{email: "mrsjd@example.com", name: "Mrs Jane Doe"}
end
> # it automatically calls notify method with event data and return only event data as response
> %{email: "mrsjd@example.com", name: "Mrs Jane Doe"}
```

### Sample Listener Implementation

```elixir
defmodule MyEventListener do
  ...

  # if your listener does not have a config
  def process({topic, id} = event_shadow) do
    GenServer.cast(__MODULE__, event_shadow)
    :ok
  end

  ...

  # if your listener has a config
  def process({config, topic, id} = event_shadow_with_conf) do
    GenServer.cast(__MODULE__, event_shadow_with_conf)
    :ok
  end

  ...


  # if your listener does not have a config
  def handle_cast({:bye_received, id}, state) do
    event = EventBus.fetch_event({:bye_received, id})
    # do sth with event

    # update the watcher!
    EventBus.mark_as_completed({__MODULE__, :bye_received, id})
    ...
    {:noreply, state}
  end

  def handle_cast({:hello_received, id}, state) do
    event = EventBus.fetch_event({:hello_received, id})
    # do sth with EventBus.Model.Event

    # update the watcher!
    EventBus.mark_as_completed({__MODULE__, :hello_received, id})
    ...
    {:noreply, state}
  end

  def handle_cast({topic, id}, state) do
    EventBus.mark_as_skipped({__MODULE__, topic, id})
    {:noreply, state}
  end

  ...

  # if your listener has a config
  def handle_cast({config, :bye_received, id}, state) do
    event = EventBus.fetch_event({:bye_received, id})
    # do sth with event

    # update the watcher!
    listener = {__MODULE__, config}
    EventBus.mark_as_completed({listener, :bye_received, id})
    ...
    {:noreply, state}
  end

  def handle_cast({config, :hello_received, id}, state) do
    event = EventBus.fetch_event({:hello_received, id})
    # do sth with EventBus.Model.Event

    # update the watcher!
    listener = {__MODULE__, config}
    EventBus.mark_as_completed({listener, :hello_received, id})
    ...
    {:noreply, state}
  end

  def handle_cast({config, topic, id}, state) do
    listener = {__MODULE__, config}
    EventBus.mark_as_skipped({listener, topic, id})
    {:noreply, state}
  end

  ...
end
```

## Event Storage Details

When an event configured in `config` file, 2 ETS tables will be created for the event on app start.

All event data is temporarily saved to the ETS tables with the name `:eb_es_<<topic>>` until all subscribers processed the data. This table is a read heavy table. When a subscriber needs to process the event data, it queries this table to fetch event data.

To watch event status, a separate watcher table is created for each event type with the name `:eb_ew_<<topic>>`. This table is used for keeping the status of the event. `Observation Manager` updates this table frequently with the notification of the event listeners/subscribers.

When all subscribers process the event data, data in the event store and watcher, automatically deleted by the `Observation Manager`. If you need to see the status of unprocessed events, event watcher table is one of the good places to query.

For example; to get the list unprocessed events for `:hello_received` event:

```elixir
# The following command will return a list of tuples with the `id`, and `event_subscribers_list` where `subscribers` is the list of event subscribers, `completers` is the subscribers those processed the event and notified `Observation Manager`, and lastly `skippers` is the subscribers those skipped the event without processing.

# Assume you have an event with the name ':hello_received'
:ets.tab2list(:eb_ew_hello_received)
> [{id, {subscribers, completers, skippers}}, ...]
```

ETS storage SHOULD NOT be considered as a persistent storage. If you need to store events to a persistant data store, then subscribe to all event types by a module with `[".*"]` event topic then save every event data.

For example;

```elixir
EventBus.subscribe({MyDataStore, [".*"]})

# then in your data store save the event
defmodule MyDataStore do
  ...

  def process({topic, id} = event_shadow) do
    GenServer.cast(__MODULE__, event_shadow)
    :ok
  end

  ...

  def handle_cast({topic, id}, state) do
    event = EventBus.fetch_event({topic, id})
    # write your logic to save event_data to a persistant store

    EventBus.mark_as_completed({__MODULE__, topic, id})
    {:noreply, state}
  end
end
```

## Traceability

EventBus comes with a good enough data structure to track the event life cycle with its optional parameters. For a traceable system, it is highly recommend to fill optional fields on event data. It is also encouraged to use `EventSource.nofify` block/yield to automatically set the `initialized_at` and `occurred_at` values.

### System Events

This feature removed with the version 1.3 to keep the core library simple. If you need to trace system events please check the sample wrapper implementation from the [wiki page](https://github.com/otobus/event_bus/wiki/Tracing-System-Events).

### EventBus.Metrics Library

EventBus has some addons to extend its optional functionalities. One of them is `event_bus_metrics` libray which comes with a UI, RESTFul endpoints and SSE streams to provide instant metrics for event_bus topics.

[EventBus.Metrics Instructions](https://github.com/otobus/event_bus/wiki/EventBus-Metrics-and-UI)

## Documentation

- [Wiki](https://github.com/otobus/event_bus/wiki)

- [Module docs](https://hexdocs.pm/event_bus)

- [The story](https://medium.com/@mustafaturan/event-bus-implementation-s-d2854a9fafd5)

## Addons

EventBus allows building generic and specific addons for your stack. Here are a few generic addons which I'm currently working on:

- `event_bus_logger` allows you to log event bus events to your console with a generic configuration: https://github.com/mustafaturan/event_bus_logger

- `event_bus_postgres` allows you to save event bus events to Postgres DB with a generic configuration: https://github.com/mustafaturan/event_bus_postgres

- `event_bus_zipkin` allows you to trace event bus events via Zipkin

- `event_bus_ddtrace` allows you to trace event bus events via Datadog APM

## Contributing

### Issues, Bugs, Documentation, Enhancements

1. Fork the project

2. Make your improvements and write your tests(make sure you covered all the cases).

3. Make a pull request.

## License

MIT

Copyright (c) 2018 Mustafa Turan

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
