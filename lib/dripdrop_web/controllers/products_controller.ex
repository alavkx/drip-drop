defmodule DripdropWeb.ProductsController do
  use DripdropWeb, :controller
  import Ecto.Query
  alias Dripdrop.Repo
  alias Dripdrop.Product

  def new(conn, _params) do
    products = from(p in Product, select: p)
    |> Repo.all
    render(conn, "new.html", products: products)
  end
end
