defmodule MemePing.Repo do
  use Ecto.Repo,
    otp_app: :memeping,
    adapter: Ecto.Adapters.SQLite3
end
