defmodule BluetteWeb.UserAuth do
  @moduledoc """
  Plugs and LiveView `on_mount` hooks for wallet-based session authentication.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias Bluette.Accounts
  alias Phoenix.LiveView

  @user_id_key "user_id"

  @spec log_in_user(Plug.Conn.t(), Accounts.User.t()) :: Plug.Conn.t()
  def log_in_user(conn, user) do
    conn
    |> configure_session(renew: true)
    |> delete_session(Accounts.session_key())
    |> put_session(@user_id_key, user.id)
  end

  @spec log_out_user(Plug.Conn.t()) :: Plug.Conn.t()
  def log_out_user(conn) do
    conn
    |> configure_session(renew: true)
    |> delete_session(@user_id_key)
  end

  @doc "Assigns `:current_user` from the session, if present."
  def fetch_current_user(conn, _opts) do
    user =
      case get_session(conn, @user_id_key) do
        nil -> nil
        id -> Accounts.get_user_with_identities(id)
      end

    assign(conn, :current_user, user)
  end

  @doc "Redirects to the login page unless a user is logged in."
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> redirect(to: "/login")
      |> halt()
    end
  end

  @doc "LiveView `on_mount` hook mirroring `require_authenticated_user/2`."
  def on_mount(:ensure_authenticated, _params, session, socket) do
    user =
      case session[@user_id_key] do
        nil -> nil
        id -> Accounts.get_user_with_identities(id)
      end

    if user do
      {:cont, Phoenix.Component.assign(socket, :current_user, user)}
    else
      {:halt, LiveView.redirect(socket, to: "/login")}
    end
  end
end
