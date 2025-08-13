defmodule Teaktable.Repo do
  use Ecto.Repo,
    otp_app: :teaktable,
    adapter: Ecto.Adapters.Postgres
end
