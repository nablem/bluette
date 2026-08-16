defmodule Bluette.Notifications.Criteria do
  @moduledoc """
  Min/max thresholds a token must fall within to trigger a notifier.

  Mirrors the metric set used by the `bentley` prototype's notifier engine
  (see `components/lib/bentley/notifiers/definition.ex`).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @metrics [
    {:age_hours, "Pair age (hours)"},
    {:market_cap, "Market cap ($)"},
    {:liquidity, "Liquidity ($)"},
    {:volume_1h, "Volume 1h ($)"},
    {:volume_6h, "Volume 6h ($)"},
    {:volume_24h, "Volume 24h ($)"},
    {:change_5m, "Price change 5m (%)"},
    {:change_1h, "Price change 1h (%)"},
    {:change_6h, "Price change 6h (%)"},
    {:change_24h, "Price change 24h (%)"},
    {:boost, "Boost"},
    {:ath, "All-time high ($)"}
  ]

  @primary_key false
  embedded_schema do
    for {metric, _label} <- @metrics do
      field :"#{metric}_min", :integer
      field :"#{metric}_max", :integer
    end
  end

  @spec metrics() :: [{atom(), String.t()}]
  def metrics, do: @metrics

  @doc false
  def changeset(criteria, attrs) do
    fields =
      Enum.flat_map(@metrics, fn {metric, _label} -> [:"#{metric}_min", :"#{metric}_max"] end)

    criteria
    |> cast(attrs, fields)
    |> validate_ranges(fields)
  end

  defp validate_ranges(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, changeset ->
      if String.ends_with?(to_string(field), "_min") do
        max_field =
          field
          |> to_string()
          |> String.replace_suffix("_min", "_max")
          |> String.to_existing_atom()

        validate_min_max(changeset, field, max_field)
      else
        changeset
      end
    end)
  end

  defp validate_min_max(changeset, min_field, max_field) do
    min = get_field(changeset, min_field)
    max = get_field(changeset, max_field)

    if is_number(min) and is_number(max) and min > max do
      add_error(changeset, min_field, "must be less than or equal to max")
    else
      changeset
    end
  end
end
