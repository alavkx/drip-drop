defmodule Dripdrop.Repo.Migrations.AddModelCodeToProductTable do
  use Ecto.Migration

  def change do
    alter table(:products) do
      remove :slot, :string
      remove :model_number, :string
      add :model_code, :string
    end
  end
end
