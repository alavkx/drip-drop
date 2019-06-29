defmodule Dripdrop.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :slot, :string
      add :model_number, :string
      add :technology_code, :string
      add :price, :integer
      add :season, :string
      add :description, :string
      add :type, :string
      add :generation, :string
      add :style, :string

      timestamps()
    end

  end
end
