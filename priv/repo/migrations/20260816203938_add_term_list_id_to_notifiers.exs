defmodule MemePing.Repo.Migrations.AddTermListIdToNotifiers do
  use Ecto.Migration

  def change do
    alter table(:notifiers) do
      add :term_list_id, references(:term_lists, on_delete: :nilify_all)
    end

    create index(:notifiers, [:term_list_id])
  end
end
