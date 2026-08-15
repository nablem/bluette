defmodule Bluette.Repo do
  use Ecto.Repo,
    otp_app: :bluette,
    adapter: Ecto.Adapters.SQLite3
end
