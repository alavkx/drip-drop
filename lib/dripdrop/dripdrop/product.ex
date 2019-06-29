defmodule Dripdrop.Dripdrop.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :description, :string
    field :generation, :string
    field :model_number, :string
    field :price, :integer
    field :season, :string
    field :slot, :string
    field :style, :string
    field :technology_code, :string
    field :type, :string

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:slot, :model_number, :technology_code, :price, :season, :description, :type, :generation, :style])
    |> validate_required([:slot, :model_number, :technology_code, :price, :season, :description, :type, :generation, :style])
  end
end
