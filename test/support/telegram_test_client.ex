defmodule Bluette.Telegram.TestClient do
  @behaviour Bluette.Telegram.Client

  @impl true
  def send_message(_chat_id, _message) do
    Application.get_env(:bluette, :telegram_test_result, :ok)
  end
end
