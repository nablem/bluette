defmodule BluetteWeb.TermListsLive do
  use BluetteWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} active_tab={:term_lists}>
      <h1 class="text-2xl font-semibold mb-2">Term lists</h1>

      <p class="opacity-70">
        Coming soon: maintain reusable forbidden-term lists (one regex per line) to attach to your notifiers.
      </p>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket), do: {:ok, socket}
end
