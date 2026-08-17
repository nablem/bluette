defmodule MemePing.Repo.Migrations.AddTelegramChannelIdToNotifiers do
  use Ecto.Migration

  def change do
    alter table(:notifiers) do
      add :telegram_channel_id, references(:telegram_channels, on_delete: :nilify_all)
    end

    create index(:notifiers, [:telegram_channel_id])
  end
end
