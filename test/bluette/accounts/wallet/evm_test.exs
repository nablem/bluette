defmodule Bluette.Accounts.Wallet.EVMTest do
  use ExUnit.Case, async: true

  alias Bluette.Accounts.Wallet.EVM

  test "verifies a personal_sign signature from the matching address" do
    {address, signature, message} =
      sign(:crypto.strong_rand_bytes(32), "Sign in to Bluette\nNonce: abc123")

    assert EVM.verify(message, signature, address)
  end

  test "rejects a signature from a different key" do
    {address, _signature, message} =
      sign(:crypto.strong_rand_bytes(32), "Sign in to Bluette\nNonce: abc123")

    {_other_address, other_signature, _message} = sign(:crypto.strong_rand_bytes(32), message)

    refute EVM.verify(message, other_signature, address)
  end

  test "rejects a signature for a different message" do
    {address, signature, message} =
      sign(:crypto.strong_rand_bytes(32), "Sign in to Bluette\nNonce: abc123")

    refute EVM.verify(message <> "tampered", signature, address)
  end

  test "rejects garbage signatures" do
    refute EVM.verify("hello", "0xnot-a-signature", "0x0000000000000000000000000000000000000000")
  end

  defp sign(private_key, message) do
    {:ok, public_key} = ExSecp256k1.create_public_key(private_key)
    address = address_from_public_key(public_key)

    hash = ExKeccak.hash_256("\x19Ethereum Signed Message:\n#{byte_size(message)}#{message}")
    {:ok, {r, s, recovery_id}} = ExSecp256k1.sign(hash, private_key)

    signature = "0x" <> Base.encode16(r <> s <> <<recovery_id + 27>>, case: :lower)

    {address, signature, message}
  end

  defp address_from_public_key(<<4, rest::binary-64>>) do
    <<_::binary-12, address::binary-20>> = ExKeccak.hash_256(rest)
    "0x" <> Base.encode16(address, case: :lower)
  end
end
