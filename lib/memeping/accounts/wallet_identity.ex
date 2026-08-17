defmodule MemePing.Accounts.WalletIdentity do
  use Ecto.Schema
  import Ecto.Changeset

  alias MemePing.Accounts.User

  @type chain :: String.t()
  @type t :: %__MODULE__{}

  @chains ["evm", "solana"]

  schema "wallet_identities" do
    field :chain, :string
    field :address, :string
    belongs_to :user, User

    timestamps()
  end

  @spec chains() :: [chain()]
  def chains, do: @chains

  @doc false
  def changeset(wallet_identity, attrs) do
    wallet_identity
    |> cast(attrs, [:chain, :address, :user_id])
    |> validate_required([:chain, :address])
    |> validate_inclusion(:chain, @chains)
    |> unique_constraint([:chain, :address])
  end
end
