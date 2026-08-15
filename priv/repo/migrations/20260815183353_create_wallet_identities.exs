defmodule Bluette.Repo.Migrations.CreateWalletIdentities do
  use Ecto.Migration

  def change do
    create table(:wallet_identities) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :chain, :string, null: false
      add :address, :string, null: false

      timestamps()
    end

    create unique_index(:wallet_identities, [:chain, :address])
    create index(:wallet_identities, [:user_id])
  end
end
