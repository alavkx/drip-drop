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
  end
end
