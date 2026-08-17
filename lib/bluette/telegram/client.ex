defmodule Bluette.Telegram.Client do
  @moduledoc """
  Behaviour and dispatch module for Telegram Bot API message delivery.
  """

  @callback send_message(String.t(), String.t()) :: :ok | {:error, term()}

  @spec send_message(String.t(), String.t()) :: :ok | {:error, term()}
  def send_message(chat_id, message) when is_binary(chat_id) and is_binary(message) do
    implementation().send_message(chat_id, message)
  end

  defp implementation do
    Application.get_env(:bluette, :telegram_client, Bluette.Telegram.HTTPClient)
  end
end
