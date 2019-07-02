defmodule Dripdrop.Repo.Migrations.AddProductSkuAssoc do
  use Ecto.Migration

  def change do
    alter table(:skus) do
      add :product_id, references(:users)
    end
  end
end
