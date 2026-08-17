defmodule MemePing.Repo.Migrations.CreateTermLists do
  use Ecto.Migration

  def change do
    create table(:term_lists) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :terms, :text, null: false

      timestamps()
    end

    create unique_index(:term_lists, [:user_id, :name])
  end
end
