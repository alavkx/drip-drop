defmodule Dripdrop.Repo.Migrations.CreateSkus do
  use Ecto.Migration

  def change do
    create table(:skus) do
      add :size, :string
      add :color, :string
      add :in_stock, :boolean, default: false, null: false

      timestamps()
    end

  end
end
