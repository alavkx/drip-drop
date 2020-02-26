defmodule Dripdrop.Product do
  use Ecto.Schema
  import Ecto.Changeset
  alias Dripdrop.SKU

  schema "products" do
    field :description, :string
    field :generation, :string
    field :model_code, :string
    field :price, :string
    field :season, :string
    field :style, :string
    field :type, :string
    has_many :skus, SKU

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [
      :model_code,
      :price,
      :season,
      :description,
      :type,
      :generation,
      :style
    ])
    |> validate_required([
      :model_code,
      :price,
      :season,
      :description,
      :type,
      :generation,
      :style
    ])
    |> unique_constraint(:model_code,
      name: :products_model_code_generation_season_id_index,
      message: "Product model + generation + season combination already exists"
    )
  end
end
