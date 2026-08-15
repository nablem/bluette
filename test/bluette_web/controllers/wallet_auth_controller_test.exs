defmodule BluetteWeb.WalletAuthControllerTest do
  use BluetteWeb.ConnCase

  describe "EVM wallet sign-in" do
    test "nonce -> sign -> verify logs the user in and reaches the dashboard", %{conn: conn} do
      private_key = :crypto.strong_rand_bytes(32)
      {:ok, public_key} = ExSecp256k1.create_public_key(private_key)
      address = evm_address(public_key)

      conn = post(conn, ~p"/auth/wallet/nonce", %{"chain" => "evm", "address" => address})
      assert %{"message" => message} = json_response(conn, 200)

      signature = sign_evm(message, private_key)

      conn =
        post(conn, ~p"/auth/wallet/verify", %{
          "chain" => "evm",
          "address" => address,
          "signature" => signature
        })

      assert %{"redirect" => "/notifiers"} = json_response(conn, 200)
      assert get_session(conn, "user_id")

      conn = get(conn, ~p"/notifiers")
      assert html_response(conn, 200) =~ String.downcase(address)
    end

    test "rejects a verify call without a matching nonce challenge", %{conn: conn} do
      private_key = :crypto.strong_rand_bytes(32)
      {:ok, public_key} = ExSecp256k1.create_public_key(private_key)
      address = evm_address(public_key)

      signature = sign_evm("some message never issued by the server", private_key)

      conn =
        post(conn, ~p"/auth/wallet/verify", %{
          "chain" => "evm",
          "address" => address,
          "signature" => signature
        })

      assert %{"error" => _reason} = json_response(conn, 401)
    end
  end

  describe "Solana wallet sign-in" do
    test "nonce -> sign -> verify logs the user in and reaches the dashboard", %{conn: conn} do
      {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)
      address = Base58.encode(public_key)

      conn = post(conn, ~p"/auth/wallet/nonce", %{"chain" => "solana", "address" => address})
      assert %{"message" => message} = json_response(conn, 200)

      signature = message |> sign_solana(private_key) |> Base58.encode()

      conn =
        post(conn, ~p"/auth/wallet/verify", %{
          "chain" => "solana",
          "address" => address,
          "signature" => signature
        })

      assert %{"redirect" => "/notifiers"} = json_response(conn, 200)

      conn = get(conn, ~p"/notifiers")
      assert html_response(conn, 200) =~ address
    end
  end

  test "GET /notifiers redirects anonymous visitors to /login", %{conn: conn} do
    conn = get(conn, ~p"/notifiers")
    assert redirected_to(conn) == "/login"
  end

  defp evm_address(<<4, rest::binary-64>>) do
    <<_::binary-12, address::binary-20>> = ExKeccak.hash_256(rest)
    "0x" <> Base.encode16(address, case: :lower)
  end

  defp sign_evm(message, private_key) do
    hash = ExKeccak.hash_256("\x19Ethereum Signed Message:\n#{byte_size(message)}#{message}")
    {:ok, {r, s, recovery_id}} = ExSecp256k1.sign(hash, private_key)
    "0x" <> Base.encode16(r <> s <> <<recovery_id + 27>>, case: :lower)
  end

  defp sign_solana(message, private_key) do
    :crypto.sign(:eddsa, :none, message, [private_key, :ed25519])
  end
end
