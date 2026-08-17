defmodule MemePing.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias MemePing.Accounts.WalletIdentity

  @type t :: %__MODULE__{}

  schema "users" do
    has_many :wallet_identities, WalletIdentity

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    cast(user, attrs, [])
  end
end
