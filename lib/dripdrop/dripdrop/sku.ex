defmodule Dripdrop.SKU do
  use Ecto.Schema
  import Ecto.Changeset
  alias Dripdrop.Product

  schema "skus" do
    field :color, :string
    field :in_stock, :boolean, default: true
    field :size, :string
    belongs_to :product, Product

    timestamps()
  end

  @doc false
  def changeset(sku, attrs \\ %{}) do
    sku
    |> cast(attrs, [:size, :color, :in_stock])
    |> validate_required([:size, :color])
    |> foreign_key_constraint(:product_id)
    |> unique_constraint(:size,
      name: :skus_size_color_product_id_index,
      message: "Product model + generation + season combination already exists"
    )
  end
end
