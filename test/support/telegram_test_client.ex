defmodule MemePing.Telegram.TestClient do
  @behaviour MemePing.Telegram.Client

  @impl true
  def send_message(_chat_id, _message) do
    Application.get_env(:memeping, :telegram_test_result, :ok)
  end
end
