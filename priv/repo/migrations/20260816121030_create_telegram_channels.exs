defmodule Bluette.Repo.Migrations.CreateTelegramChannels do
  use Ecto.Migration

  def change do
    create table(:telegram_channels) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :chat_id, :string, null: false

      timestamps()
    end

    create unique_index(:telegram_channels, [:user_id, :name])
    create unique_index(:telegram_channels, [:user_id, :chat_id])
  end
end
