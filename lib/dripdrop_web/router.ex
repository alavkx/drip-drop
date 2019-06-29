defmodule DripdropWeb.Router do
  use DripdropWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DripdropWeb do
    pipe_through :browser

    get "/", UserController, :new
    post "/user", UserController, :create
  end

  # Other scopes may use custom stacks.
  # scope "/api", DripdropWeb do
  #   pipe_through :api
  # end
end
