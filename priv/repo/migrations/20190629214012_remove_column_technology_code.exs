defmodule Dripdrop.Repo.Migrations.RemoveColumnTechnologyCode do
  use Ecto.Migration

  def change do
    alter table(:products) do
      remove :technology_code, :string
    end
  end
end
