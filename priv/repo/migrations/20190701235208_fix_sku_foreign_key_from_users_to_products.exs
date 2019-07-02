defmodule Dripdrop.Repo.Migrations.FixSkuForeignKeyFromUsersToProducts do
  use Ecto.Migration

  def change do
    execute "ALTER TABLE skus DROP CONSTRAINT skus_product_id_fkey"

    alter table(:skus) do
      modify :product_id, references(:products, on_delete: :delete_all)
    end
  end
end
