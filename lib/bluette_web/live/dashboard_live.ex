defmodule BluetteWeb.DashboardLive do
  use BluetteWeb, :live_view

  alias Bluette.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-lg mt-24 text-center">
      <h1 class="text-2xl font-semibold mb-4">Bluette dashboard</h1>
      <p class="mb-2">Logged in as:</p>
      <ul class="mb-6">
        <li :for={identity <- @wallet_identities} class="font-mono text-sm">
          {identity.chain}: {identity.address}
        </li>
      </ul>
      <.link href="/logout" method="delete" class="btn">Log out</.link>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    identities = Accounts.wallet_identities(socket.assigns.current_user)
    {:ok, assign(socket, :wallet_identities, identities)}
  end
end
