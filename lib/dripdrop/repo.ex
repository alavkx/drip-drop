defmodule Dripdrop.Repo do
  use Ecto.Repo,
    otp_app: :dripdrop,
    adapter: Ecto.Adapters.Postgres
end
