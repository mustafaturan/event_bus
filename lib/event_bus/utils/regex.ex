defmodule EventBus.Util.Regex do
  @moduledoc false
  # Regex util for event bus

  @doc """
  It checks if the given list of keys includes the key.
  """
  @spec superset?(list(String.t() | atom()), String.t() | atom()) :: boolean()
  def superset?(keys, key) do
    regex_pattern = build_regex_pattern(keys)

    case Regex.compile(regex_pattern) do
      {:ok, pattern} -> Regex.match?(pattern, "#{key}")
      _ -> false
    end
  end

  @spec build_regex_pattern(list(String.t() | atom())) :: String.t()
  defp build_regex_pattern(keys) do
    keys
    |> Enum.map(fn key -> "^(#{key})" end)
    |> Enum.join("|")
  end
end
