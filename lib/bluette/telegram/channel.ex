defmodule Bluette.Telegram.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  alias Bluette.Accounts.User
  alias Bluette.Notifications.Notifier

  @type t :: %__MODULE__{}

  schema "telegram_channels" do
    field :name, :string
    field :chat_id, :string
    belongs_to :user, User
    has_many :notifiers, Notifier, foreign_key: :telegram_channel_id

    timestamps()
  end

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :chat_id, :user_id])
    |> validate_required([:name, :chat_id, :user_id])
    |> validate_length(:name, max: 50)
    |> validate_length(:chat_id, max: 100)
    |> unique_constraint(:name, name: :telegram_channels_user_id_name_index)
    |> unique_constraint(:chat_id, name: :telegram_channels_user_id_chat_id_index)
  end
end
