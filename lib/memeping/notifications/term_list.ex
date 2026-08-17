defmodule MemePing.Notifications.TermList do
  use Ecto.Schema
  import Ecto.Changeset

  alias MemePing.Accounts.User
  alias MemePing.Notifications.Notifier

  @type t :: %__MODULE__{}

  schema "term_lists" do
    field :name, :string
    field :terms, :string
    belongs_to :user, User
    has_many :notifiers, Notifier, foreign_key: :term_list_id

    timestamps()
  end

  @doc false
  def changeset(term_list, attrs) do
    term_list
    |> cast(attrs, [:name, :terms, :user_id])
    |> update_change(:terms, &normalize_terms/1)
    |> validate_required([:name, :terms, :user_id])
    |> validate_length(:name, max: 50)
    |> unique_constraint(:name, name: :term_lists_user_id_name_index)
    |> validate_terms()
  end

  defp normalize_terms(terms) do
    terms
    |> String.split(~r/\R/u)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp validate_terms(changeset) do
    case get_change(changeset, :terms) || get_field(changeset, :terms) do
      nil ->
        changeset

      terms ->
        terms
        |> String.split("\n", trim: true)
        |> Enum.reduce(changeset, &validate_term(&2, &1))
    end
  end

  defp validate_term(changeset, term) do
    case Regex.compile(term, "i") do
      {:ok, _regex} -> changeset
      {:error, _reason} -> add_error(changeset, :terms, "contains an invalid regex: #{term}")
    end
  end
end
