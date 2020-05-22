use Mix.Config

config :logger, level: :info

config :dripdrop, DripdropWeb.Endpoint,
  # Possibly not needed, but doesn't hurt
  http: [port: {:system, "PORT"}],
  url: [host: "${APP_NAME}.gigalixirapp.com", port: 80],
  secret_key_base: "${SECRET_KEY_BASE}",
  server: true

config :dripdrop, Dripdrop.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: "${DATABASE_URL}",
  ssl: true,
  # Free tier db only allows 4 connections. Rolling deploys need pool_size*(n+1) connections.
  pool_size: 2

config :dripdrop,
       :webhook,
       "${WEBHOOK}"
