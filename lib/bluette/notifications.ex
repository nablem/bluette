defmodule Bluette.Notifications do
  @moduledoc """
  CRUD for a user's notifiers (Telegram destination + match criteria).

  This is UI/data-capture only for now: nothing here polls DEX Screener or sends
  Telegram messages yet.
  """

  import Ecto.Query

  alias Bluette.Accounts.User
  alias Bluette.Notifications.Criteria
  alias Bluette.Notifications.Notifier
  alias Bluette.Repo

  @spec list_notifiers(User.t()) :: [Notifier.t()]
  def list_notifiers(%User{id: user_id}) do
    Notifier
    |> where([n], n.user_id == ^user_id)
    |> preload(:telegram_channel_record)
    |> order_by([n], asc: n.name)
    |> Repo.all()
  end

  @spec get_notifier!(User.t(), pos_integer() | String.t()) :: Notifier.t()
  def get_notifier!(%User{id: user_id}, id) do
    Notifier
    |> where([n], n.user_id == ^user_id)
    |> preload(:telegram_channel_record)
    |> Repo.get!(id)
  end

  @spec new_notifier() :: Notifier.t()
  def new_notifier, do: %Notifier{criteria: %Criteria{}}

  @spec change_notifier(Notifier.t(), map()) :: Ecto.Changeset.t()
  def change_notifier(%Notifier{} = notifier, attrs \\ %{}) do
    Notifier.changeset(notifier, attrs)
  end

  @spec create_notifier(User.t(), map()) :: {:ok, Notifier.t()} | {:error, Ecto.Changeset.t()}
  def create_notifier(%User{id: user_id}, attrs) do
    %Notifier{}
    |> Notifier.changeset(Map.put(attrs, "user_id", user_id))
    |> Repo.insert()
  end

  @spec update_notifier(Notifier.t(), map()) :: {:ok, Notifier.t()} | {:error, Ecto.Changeset.t()}
  def update_notifier(%Notifier{} = notifier, attrs) do
    notifier
    |> Notifier.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_notifier(Notifier.t()) :: {:ok, Notifier.t()} | {:error, Ecto.Changeset.t()}
  def delete_notifier(%Notifier{} = notifier), do: Repo.delete(notifier)

  @spec metrics() :: [{atom(), String.t()}]
  def metrics, do: Criteria.metrics()
end
