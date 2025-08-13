defmodule Teaktable.DeckTest do
  use Teaktable.DataCase

  alias Teaktable.Deck

  describe "cards" do
    alias Teaktable.Deck.Card

    import Teaktable.DeckFixtures

    @invalid_attrs %{type: nil, description: nil, title: nil, score: nil}

    test "list_cards/0 returns all cards" do
      card = card_fixture()
      assert Deck.list_cards() == [card]
    end

    test "get_card!/1 returns the card with given id" do
      card = card_fixture()
      assert Deck.get_card!(card.id) == card
    end

    test "create_card/1 with valid data creates a card" do
      valid_attrs = %{type: :monikers, description: "some description", title: "some title", score: 42}

      assert {:ok, %Card{} = card} = Deck.create_card(valid_attrs)
      assert card.type == :monikers
      assert card.description == "some description"
      assert card.title == "some title"
      assert card.score == 42
    end

    test "create_card/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Deck.create_card(@invalid_attrs)
    end

    test "update_card/2 with valid data updates the card" do
      card = card_fixture()
      update_attrs = %{type: :cahwhite, description: "some updated description", title: "some updated title", score: 43}

      assert {:ok, %Card{} = card} = Deck.update_card(card, update_attrs)
      assert card.type == :cahwhite
      assert card.description == "some updated description"
      assert card.title == "some updated title"
      assert card.score == 43
    end

    test "update_card/2 with invalid data returns error changeset" do
      card = card_fixture()
      assert {:error, %Ecto.Changeset{}} = Deck.update_card(card, @invalid_attrs)
      assert card == Deck.get_card!(card.id)
    end

    test "delete_card/1 deletes the card" do
      card = card_fixture()
      assert {:ok, %Card{}} = Deck.delete_card(card)
      assert_raise Ecto.NoResultsError, fn -> Deck.get_card!(card.id) end
    end

    test "change_card/1 returns a card changeset" do
      card = card_fixture()
      assert %Ecto.Changeset{} = Deck.change_card(card)
    end
  end
end
