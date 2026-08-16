defmodule Bluette.Notifications.TermLists do
  @moduledoc """
  CRUD for reusable, case-insensitive forbidden regex lists.
  """

  import Ecto.Query

  alias Bluette.Accounts.User
  alias Bluette.Notifications.TermList
  alias Bluette.Repo

  @spec list_term_lists(User.t()) :: [TermList.t()]
  def list_term_lists(%User{id: user_id}) do
    TermList
    |> where([term_list], term_list.user_id == ^user_id)
    |> order_by([term_list], asc: term_list.name)
    |> Repo.all()
  end

  @spec get_term_list!(User.t(), pos_integer() | String.t()) :: TermList.t()
  def get_term_list!(%User{id: user_id}, id) do
    TermList
    |> where([term_list], term_list.user_id == ^user_id)
    |> Repo.get!(id)
  end

  @spec new_term_list() :: TermList.t()
  def new_term_list, do: %TermList{}

  @spec change_term_list(TermList.t(), map()) :: Ecto.Changeset.t()
  def change_term_list(%TermList{} = term_list, attrs \\ %{}),
    do: TermList.changeset(term_list, attrs)

  @spec create_term_list(User.t(), map()) :: {:ok, TermList.t()} | {:error, Ecto.Changeset.t()}
  def create_term_list(%User{id: user_id}, attrs) do
    %TermList{}
    |> TermList.changeset(Map.put(attrs, "user_id", user_id))
    |> Repo.insert()
  end

  @spec update_term_list(TermList.t(), map()) ::
          {:ok, TermList.t()} | {:error, Ecto.Changeset.t()}
  def update_term_list(%TermList{} = term_list, attrs) do
    term_list
    |> TermList.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_term_list(TermList.t()) :: {:ok, TermList.t()} | {:error, Ecto.Changeset.t()}
  def delete_term_list(%TermList{} = term_list), do: Repo.delete(term_list)
end
