defmodule Bluette.Accounts.Wallet.EVM do
  @moduledoc """
  Verifies `personal_sign` (EIP-191) signatures produced by MetaMask and similar wallets.
  """

  @spec verify(String.t(), String.t(), String.t()) :: boolean()
  def verify(message, signature, address)
      when is_binary(message) and is_binary(signature) and is_binary(address) do
    with {:ok, <<r::binary-32, s::binary-32, v>>} <- decode_signature(signature),
         {:ok, recovery_id} <- normalize_recovery_id(v),
         hash <- ExKeccak.hash_256(prefixed_message(message)),
         {:ok, public_key} <- ExSecp256k1.recover_compact(hash, r <> s, recovery_id) do
      derive_address(public_key) == normalize_address(address)
    else
      _ -> false
    end
  end

  defp decode_signature("0x" <> hex), do: decode_signature(hex)

  defp decode_signature(hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, <<_::binary-65>> = bin} -> {:ok, bin}
      _ -> :error
    end
  end

  defp normalize_recovery_id(v) when v in [27, 28], do: {:ok, v - 27}
  defp normalize_recovery_id(v) when v in [0, 1], do: {:ok, v}
  defp normalize_recovery_id(_v), do: :error

  defp prefixed_message(message) do
    "\x19Ethereum Signed Message:\n#{byte_size(message)}#{message}"
  end

  defp derive_address(<<4, rest::binary-64>>) do
    <<_::binary-12, address::binary-20>> = ExKeccak.hash_256(rest)
    "0x" <> Base.encode16(address, case: :lower)
  end

  defp derive_address(_), do: nil

  defp normalize_address(address), do: String.downcase(address)
end
