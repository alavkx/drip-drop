defmodule DripdropWeb.ProductsController do
  use DripdropWeb, :controller
  import Ecto.Query
  alias Dripdrop.Repo
  alias Dripdrop.Product

  def render(conn, _params) do
    products =
      from(p in Product, select: p)
      |> Repo.all()

    render(conn, "products.html", products: products)
  end
end
