defmodule BluetteWeb.TelegramChannelsLive do
  use BluetteWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} active_tab={:telegram_channels}>
      <h1 class="text-2xl font-semibold mb-2">Telegram channels</h1>

      <p class="opacity-70">
        Coming soon: link the Telegram channels you own so you can pick them when creating a notifier.
      </p>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket), do: {:ok, socket}
end
