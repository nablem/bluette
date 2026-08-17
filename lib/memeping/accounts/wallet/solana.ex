defmodule MemePing.Accounts.Wallet.Solana do
  @moduledoc """
  Verifies ed25519 message signatures produced by Phantom and similar wallets.

  Addresses and signatures are expected to be Base58-encoded, matching Solana conventions.
  """

  @spec verify(String.t(), String.t(), String.t()) :: boolean()
  def verify(message, signature, address)
      when is_binary(message) and is_binary(signature) and is_binary(address) do
    with {:ok, public_key} <- decode58(address, 32),
         {:ok, signature_bytes} <- decode58(signature, 64) do
      :crypto.verify(:eddsa, :none, message, signature_bytes, [public_key, :ed25519])
    else
      _ -> false
    end
  end

  defp decode58(value, expected_size) do
    case Base58.decode(value) do
      binary when is_binary(binary) and byte_size(binary) == expected_size -> {:ok, binary}
      _ -> :error
    end
  rescue
    _ -> :error
  end
end
