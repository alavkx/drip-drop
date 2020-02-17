defmodule Dripdrop.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Dripdrop.Repo,
      DripdropWeb.Endpoint,
      Dripdrop.Crawl
    ]

    opts = [strategy: :one_for_one, name: Dripdrop.Supervisor, restart: :permanent]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    DripdropWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
