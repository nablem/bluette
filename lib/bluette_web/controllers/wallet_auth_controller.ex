defmodule BluetteWeb.WalletAuthController do
  use BluetteWeb, :controller

  alias Bluette.Accounts
  alias BluetteWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new)
  end

  def nonce(conn, %{"chain" => chain, "address" => address})
      when chain in ["evm", "solana"] and is_binary(address) do
    {message, session_updates} = Accounts.build_challenge(chain, address)

    conn =
      Enum.reduce(session_updates, conn, fn {key, value}, conn ->
        put_session(conn, key, value)
      end)

    json(conn, %{message: message})
  end

  def nonce(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "invalid_request"})
  end

  def verify(conn, params) do
    session_challenge = get_session(conn, Accounts.session_key())

    case Accounts.verify_login(session_challenge, params) do
      {:ok, user} ->
        conn
        |> UserAuth.log_in_user(user)
        |> json(%{redirect: "/notifiers"})

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: to_string(reason)})
    end
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
    |> redirect(to: "/login")
  end
end
