defmodule BluetteWeb.NotifiersLive do
  use BluetteWeb, :live_view

  alias Bluette.Notifications
  alias Bluette.Notifications.Notifier

  def render(%{live_action: :index} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} active_tab={:notifiers}>
      <div class="flex items-center justify-between mb-4">
        <h1 class="text-2xl font-semibold">Notifiers</h1>
         <.link navigate={~p"/notifiers/new"} class="btn btn-primary btn-sm">New notifier</.link>
      </div>
      
      <p :if={@notifiers == []} class="opacity-70">
        No notifiers yet. Create one to start receiving calls on Telegram.
      </p>
      
      <table :if={@notifiers != []} class="table">
        <thead>
          <tr>
            <th>Name</th>
            
            <th>Chain</th>
            
            <th>Telegram channel</th>
            
            <th>Term list</th>
            
            <th>Status</th>
            
            <th></th>
          </tr>
        </thead>
        
        <tbody>
          <tr :for={notifier <- @notifiers}>
            <td>{notifier.name}</td>
            
            <td>{notifier.chain}</td>
            
            <td>{notifier.telegram_channel || "—"}</td>
            
            <td>{notifier.forbidden_term_list || "—"}</td>
            
            <td>
              <span class={[
                "badge",
                notifier.enabled && "badge-success",
                !notifier.enabled && "badge-ghost"
              ]}>
                {if notifier.enabled, do: "enabled", else: "disabled"}
              </span>
            </td>
            
            <td class="flex gap-2 justify-end">
              <.link navigate={~p"/notifiers/#{notifier}/edit"} class="btn btn-ghost btn-xs">
                Edit
              </.link>
              <.link
                phx-click={JS.push("delete", value: %{id: notifier.id})}
                data-confirm={"Delete notifier \"#{notifier.name}\"?"}
                class="btn btn-ghost btn-xs text-error"
              >
                Delete
              </.link>
            </td>
          </tr>
        </tbody>
      </table>
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} active_tab={:notifiers}>
      <h1 class="text-2xl font-semibold mb-4">
        {if @live_action == :new, do: "New notifier", else: "Edit notifier"}
      </h1>
      
      <.form for={@form} id="notifier-form" phx-change="validate" phx-submit="save" class="space-y-6">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <.input field={@form[:name]} type="text" label="Name" placeholder="e.g. New Solana pairs" />
          <.input field={@form[:chain]} type="select" label="Chain" options={Notifier.chains()} />
          <.input
            field={@form[:telegram_channel]}
            type="select"
            label="Telegram channel"
            options={[{"— none linked yet —", nil} | Notifier.placeholder_telegram_channels()]}
          />
          <.input
            field={@form[:forbidden_term_list]}
            type="select"
            label="Forbidden term list"
            options={[{"— none linked yet —", nil} | Notifier.placeholder_forbidden_term_lists()]}
          /> <.input field={@form[:enabled]} type="checkbox" label="Enabled" />
        </div>
        
        <div>
          <h2 class="text-lg font-semibold mb-2">Match criteria</h2>
          
          <p class="text-sm mb-3">
            <strong class="text-primary">
              Leave both min and max blank for metrics this notifier does not depend on.
              A single value sets only that lower or upper bound.
            </strong>
          </p>
          
          <.inputs_for :let={cf} field={@form[:criteria]}>
            <table class="table">
              <thead>
                <tr>
                  <th>Metric</th>
                  
                  <th>Min</th>
                  
                  <th>Max</th>
                </tr>
              </thead>
              
              <tbody>
                <tr :for={{metric, label} <- Notifications.metrics()}>
                  <td>{label}</td>
                  
                  <td><.input field={cf[:"#{metric}_min"]} type="number" step="any" /></td>
                  
                  <td><.input field={cf[:"#{metric}_max"]} type="number" step="any" /></td>
                </tr>
              </tbody>
            </table>
          </.inputs_for>
        </div>
        
        <div class="flex gap-2">
          <.button type="submit" phx-disable-with="Saving...">Save notifier</.button>
          <.link navigate={~p"/notifiers"} class="btn btn-ghost">Cancel</.link>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :notifiers, Notifications.list_notifiers(socket.assigns.current_user))}
  end

  def handle_params(%{"id" => id}, _uri, %{assigns: %{live_action: :edit}} = socket) do
    notifier = Notifications.get_notifier!(socket.assigns.current_user, id)

    {:noreply,
     socket
     |> assign(:notifier, notifier)
     |> assign(:form, to_form(Notifications.change_notifier(notifier)))}
  end

  def handle_params(_params, _uri, %{assigns: %{live_action: :new}} = socket) do
    notifier = Notifications.new_notifier()

    {:noreply,
     socket
     |> assign(:notifier, notifier)
     |> assign(:form, to_form(Notifications.change_notifier(notifier)))}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  def handle_event("validate", %{"notifier" => params}, socket) do
    form =
      socket.assigns.notifier
      |> Notifications.change_notifier(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"notifier" => params}, socket) do
    save_notifier(socket, socket.assigns.live_action, params)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    notifier = Notifications.get_notifier!(socket.assigns.current_user, id)
    {:ok, _} = Notifications.delete_notifier(notifier)

    {:noreply,
     assign(socket, :notifiers, Notifications.list_notifiers(socket.assigns.current_user))}
  end

  defp save_notifier(socket, :new, params) do
    case Notifications.create_notifier(socket.assigns.current_user, params) do
      {:ok, _notifier} ->
        {:noreply,
         socket
         |> put_flash(:info, "Notifier created")
         |> push_navigate(to: ~p"/notifiers")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_notifier(socket, :edit, params) do
    case Notifications.update_notifier(socket.assigns.notifier, params) do
      {:ok, _notifier} ->
        {:noreply,
         socket
         |> put_flash(:info, "Notifier updated")
         |> push_navigate(to: ~p"/notifiers")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
