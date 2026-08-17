defmodule MemePing.Repo.Migrations.AddUniqueIndexToNotifiersUserName do
  use Ecto.Migration

  def change do
    rename_existing_duplicates()
    create unique_index(:notifiers, [:user_id, :name])
  end

  defp rename_existing_duplicates do
    repo().query!("""
    SELECT user_id, name
    FROM notifiers
    GROUP BY user_id, name
    HAVING COUNT(*) > 1
    """)
    |> then(fn result -> result.rows end)
    |> Enum.each(fn [user_id, name] ->
      repo().query!(
        "SELECT id FROM notifiers WHERE user_id = ? AND name = ? ORDER BY id",
        [user_id, name]
      )
      |> Map.fetch!(:rows)
      |> Enum.drop(1)
      |> Enum.with_index(2)
      |> Enum.each(fn {[id], suffix} ->
        repo().query!("UPDATE notifiers SET name = ? WHERE id = ?", ["#{name} (#{suffix})", id])
      end)
    end)
  end
end
