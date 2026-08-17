defmodule MemePing.Repo.Migrations.CreateNotifiers do
  use Ecto.Migration

  def change do
    create table(:notifiers) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :chain, :string, null: false
      add :enabled, :boolean, null: false, default: true
      add :telegram_channel, :string
      add :forbidden_term_list, :string
      add :criteria, :map, null: false, default: %{}

      timestamps()
    end

    create index(:notifiers, [:user_id])
  end
end
