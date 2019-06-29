defmodule Dripdrop.Repo.Migrations.AlterPriceTypeToString do
  use Ecto.Migration

  def change do
    alter table(:products) do
      modify :price, :string
    end
  end
end
