defmodule Bluette.Telegram do
  @moduledoc """
  CRUD for a user's Telegram channel destinations.

  Connectivity and test-message delivery are intentionally deferred.
  """

  import Ecto.Query

  alias Bluette.Accounts.User
  alias Bluette.Repo
  alias Bluette.Telegram.Channel
  alias Bluette.Telegram.Client

  @spec list_channels(User.t()) :: [Channel.t()]
  def list_channels(%User{id: user_id}) do
    Channel
    |> where([channel], channel.user_id == ^user_id)
    |> order_by([channel], asc: channel.name)
    |> Repo.all()
  end

  @spec get_channel!(User.t(), pos_integer() | String.t()) :: Channel.t()
  def get_channel!(%User{id: user_id}, id) do
    Channel
    |> where([channel], channel.user_id == ^user_id)
    |> Repo.get!(id)
  end

  @spec new_channel() :: Channel.t()
  def new_channel, do: %Channel{}

  @spec change_channel(Channel.t(), map()) :: Ecto.Changeset.t()
  def change_channel(%Channel{} = channel, attrs \\ %{}), do: Channel.changeset(channel, attrs)

  @spec create_channel(User.t(), map()) :: {:ok, Channel.t()} | {:error, Ecto.Changeset.t()}
  def create_channel(%User{id: user_id}, attrs) do
    %Channel{}
    |> Channel.changeset(Map.put(attrs, "user_id", user_id))
    |> Repo.insert()
  end

  @spec update_channel(Channel.t(), map()) :: {:ok, Channel.t()} | {:error, Ecto.Changeset.t()}
  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_channel(Channel.t()) :: {:ok, Channel.t()} | {:error, Ecto.Changeset.t()}
  def delete_channel(%Channel{} = channel), do: Repo.delete(channel)

  @spec send_test_message(Channel.t()) :: :ok | {:error, term()}
  def send_test_message(%Channel{chat_id: chat_id, name: name}) do
    Client.send_message(
      chat_id,
      "Bluette test message\n\nThis channel is ready to receive memecoin calls for #{name}."
    )
  end
end
