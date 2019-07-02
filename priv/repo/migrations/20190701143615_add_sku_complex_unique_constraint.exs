defmodule Dripdrop.Repo.Migrations.AddSkuComplexUniqueConstraint do
  use Ecto.Migration

  def change do
    create unique_index(:skus, [:size, :color, :product_id])
  end
end
