defmodule EventBus.EventSourceTest do
  use ExUnit.Case
  use EventBus.EventSource

  doctest EventSource

  setup do
    EventBus.register_topic(:user_created)
    :ok
  end

  test "build with all params" do
    id = 1
    topic = :user_created
    data = %{id: 1, name: "me", email: "me@example.com"}
    transaction_id = "t1"
    ttl = 100

    params = %{
      id: id,
      topic: topic,
      transaction_id: transaction_id,
      ttl: ttl,
      source: "me"
    }

    event =
      EventSource.build(params, fn ->
        Process.sleep(1_000)
        data
      end)

    assert event.data == data
    assert event.id == id
    assert event.topic == topic
    assert event.transaction_id == transaction_id
    assert event.ttl == ttl
    assert event.source == "me"
    refute is_nil(event.initialized_at)
    refute is_nil(event.occurred_at)
    assert Event.duration(event) > 0
  end

  test "build without passing source" do
    topic = :user_created

    event =
      EventSource.build(%{topic: topic}, fn ->
        "some event data"
      end)

    assert event.source == "EventBus.EventSourceTest"
  end

  test "build without passing ttl, sets the ttl from app configuration" do
    topic = :user_created

    event =
      EventSource.build(%{topic: topic}, fn ->
        "some event data"
      end)

    assert event.ttl == 30_000_000
  end

  test "build without passing id, sets the id with unique_id function" do
    topic = :user_created

    event =
      EventSource.build(%{topic: topic}, fn ->
        "some event data"
      end)

    refute is_nil(event.id)
  end

  test "build with error topic" do
    id = 1
    topic = :user_created
    error_topic = :user_create_erred
    data = %{email: "Invalid format"}
    transaction_id = "t1"
    ttl = 100

    event =
      EventSource.build(
        %{
          id: id,
          topic: topic,
          transaction_id: transaction_id,
          ttl: ttl,
          error_topic: error_topic
        },
        fn ->
          {:error, data}
        end
      )

    assert event.data == {:error, data}
    assert event.id == id
    assert event.topic == error_topic
    assert event.transaction_id == transaction_id
    assert event.ttl == ttl
    assert event.source == "EventBus.EventSourceTest"
    refute is_nil(event.initialized_at)
    refute is_nil(event.occurred_at)
  end

  test "notify" do
    id = 1
    topic = :user_created
    data = %{id: 1, name: "me", email: "me@example.com"}

    result =
      EventSource.notify(%{id: id, topic: topic}, fn ->
        data
      end)

    assert result == data
  end
end
