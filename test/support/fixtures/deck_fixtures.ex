defmodule Teaktable.DeckFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Teaktable.Deck` context.
  """

  @doc """
  Generate a card.
  """
  def card_fixture(attrs \\ %{}) do
    {:ok, card} =
      attrs
      |> Enum.into(%{
        description: "some description",
        score: 42,
        title: "some title",
        type: :monikers
      })
      |> Teaktable.Deck.create_card()

    card
  end
end
