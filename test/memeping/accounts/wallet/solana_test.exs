defmodule MemePing.Accounts.Wallet.SolanaTest do
  use ExUnit.Case, async: true

  alias MemePing.Accounts.Wallet.Solana

  test "verifies an ed25519 signature from the matching address" do
    {address, signature, message} = sign("Sign in to MemePing\nNonce: abc123")

    assert Solana.verify(message, signature, address)
  end

  test "rejects a signature from a different key" do
    {address, _signature, message} = sign("Sign in to MemePing\nNonce: abc123")
    {_other_address, other_signature, _message} = sign(message)

    refute Solana.verify(message, other_signature, address)
  end

  test "rejects a signature for a different message" do
    {address, signature, message} = sign("Sign in to MemePing\nNonce: abc123")

    refute Solana.verify(message <> "tampered", signature, address)
  end

  test "rejects garbage input" do
    refute Solana.verify("hello", "not-base58-!!!", "also-not-base58-!!!")
  end

  defp sign(message) do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)
    signature = :crypto.sign(:eddsa, :none, message, [private_key, :ed25519])

    {Base58.encode(public_key), Base58.encode(signature), message}
  end
end
