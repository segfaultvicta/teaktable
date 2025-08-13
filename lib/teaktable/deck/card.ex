defmodule Teaktable.Deck.Card do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cards" do
    field :title, :string
    field :description, :string
    field :score, :integer
    field :type, Ecto.Enum, values: [:monikers, :cahwhite, :cahblack]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(card, attrs) do
    card
    |> cast(attrs, [:title, :description, :score, :type])
    |> validate_required([:description, :type])
  end
end
