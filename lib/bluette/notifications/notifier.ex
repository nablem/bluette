defmodule Bluette.Notifications.Notifier do
  use Ecto.Schema
  import Ecto.Changeset

  alias Bluette.Accounts.User
  alias Bluette.Notifications.Criteria
  alias Bluette.Telegram.Channel

  @type t :: %__MODULE__{}

  @chains ["solana", "ethereum", "base", "bsc"]

  @placeholder_forbidden_term_lists ["default-scam-terms", "nsfw-terms"]

  schema "notifiers" do
    field :name, :string
    field :chain, :string
    field :enabled, :boolean, default: true
    field :telegram_channel, :string
    field :forbidden_term_list, :string
    belongs_to :user, User
    belongs_to :telegram_channel_record, Channel, foreign_key: :telegram_channel_id

    embeds_one :criteria, Criteria, on_replace: :update

    timestamps()
  end

  @spec chains() :: [String.t()]
  def chains, do: @chains

  @spec placeholder_forbidden_term_lists() :: [String.t()]
  def placeholder_forbidden_term_lists, do: @placeholder_forbidden_term_lists

  @doc false
  def changeset(notifier, attrs) do
    notifier
    |> cast(attrs, [
      :name,
      :chain,
      :enabled,
      :telegram_channel_id,
      :forbidden_term_list,
      :user_id
    ])
    |> cast_embed(:criteria)
    |> validate_required([:name, :chain, :user_id])
    |> validate_length(:name, max: 25)
    |> validate_inclusion(:chain, @chains)
    |> unique_constraint(:name, name: :notifiers_user_id_name_index)
  end
end
