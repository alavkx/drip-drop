defmodule Dripdrop.Repo.Migrations.AddProductComplexUniqueConstraint do
  use Ecto.Migration

  def change do
    create unique_index(:products, [:model_code, :generation, :season])
  end
end
