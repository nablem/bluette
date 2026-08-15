defmodule Bluette.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BluetteWeb.Telemetry,
      Bluette.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:bluette, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:bluette, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Bluette.PubSub},
      # Start a worker by calling: Bluette.Worker.start_link(arg)
      # {Bluette.Worker, arg},
      # Start to serve requests, typically the last entry
      BluetteWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Bluette.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BluetteWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
