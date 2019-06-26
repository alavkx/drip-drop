defmodule DripdropWeb.PageController do
  use DripdropWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
