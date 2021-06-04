defmodule EventBus.Util.Base62 do
  @moduledoc false

  @mapping '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'

  @doc """
  Generates partially sequential, base62 unique identifier.
  """
  @spec unique_id() :: String.t()
  def unique_id do
    now() <> node_id() <> random(4, 14_776_336)
  end

  @doc """
  Converts given integer to base62.
  """
  @spec encode(integer()) :: String.t()
  def encode(num) when num < 62 do
    << Enum.at(@mapping, num) >>
  end

  def encode(num) do
    encode(div(num, 62)) <> encode(rem(num, 62))
  end

  # Generates random base62 string with crypto:strong_rand_bytes
  defp random(size, max) do
    size
    |> :crypto.strong_rand_bytes()
    |> :crypto.bytes_to_integer()
    |> rem(max)
    |> encode()
    |> String.pad_leading(size, "0")
  end

  # Current time (microsecond) encoded in base62
  defp now do
    encode(System.os_time(:microsecond))
  end

  # Assigns a random node_id on first call
  defp node_id do
    case Application.get_env(:event_bus, :node_id) do
      nil -> save_node_id(random(3, 238_328))
      nid -> nid
    end
  end

  defp save_node_id(node_id) do
    Application.put_env(:event_bus, :node_id, node_id, persistent: true)
    node_id
  end
end
