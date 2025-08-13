defmodule Teaktable.Repo.Migrations.CreateCards do
  use Ecto.Migration

  def change do
    create table(:cards) do
      add :title, :string
      add :description, :string
      add :score, :integer
      add :type, :string

      timestamps(type: :utc_datetime)
    end
  end
end
