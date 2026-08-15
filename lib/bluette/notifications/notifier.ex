defmodule Bluette.Notifications.Notifier do
  use Ecto.Schema
  import Ecto.Changeset

  alias Bluette.Accounts.User
  alias Bluette.Notifications.Criteria

  @type t :: %__MODULE__{}

  @chains ["solana", "ethereum", "base", "bsc"]

  # Placeholder options until the Telegram Channels / Term Lists tabs exist for real.
  @placeholder_telegram_channels ["alpha-calls", "main-channel", "vip-room"]
  @placeholder_forbidden_term_lists ["default-scam-terms", "nsfw-terms"]

  schema "notifiers" do
    field :name, :string
    field :chain, :string
    field :enabled, :boolean, default: true
    field :telegram_channel, :string
    field :forbidden_term_list, :string
    belongs_to :user, User

    embeds_one :criteria, Criteria, on_replace: :update

    timestamps()
  end

  @spec chains() :: [String.t()]
  def chains, do: @chains

  @spec placeholder_telegram_channels() :: [String.t()]
  def placeholder_telegram_channels, do: @placeholder_telegram_channels

  @spec placeholder_forbidden_term_lists() :: [String.t()]
  def placeholder_forbidden_term_lists, do: @placeholder_forbidden_term_lists

  @doc false
  def changeset(notifier, attrs) do
    notifier
    |> cast(attrs, [:name, :chain, :enabled, :telegram_channel, :forbidden_term_list, :user_id])
    |> cast_embed(:criteria)
    |> validate_required([:name, :chain, :user_id])
    |> validate_inclusion(:chain, @chains)
  end
end
