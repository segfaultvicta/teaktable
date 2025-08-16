defmodule TeaktableWeb.CardHTML do
  use TeaktableWeb, :html

  embed_templates "card_html/*"
end

defmodule TeaktableWeb.CardController do
  use TeaktableWeb, :controller

  alias Teaktable.Deck
  alias Teaktable.Deck.Card

  def index(conn, _params) do
    cards = Deck.list_cards()

    render(conn, :index,
      cards: Enum.map(cards, fn card -> %{card | type: translate_type(card.type)} end)
    )
  end

  defp translate_type(type) do
    case type do
      :monikers -> "Monikers"
      :cahwhite -> "Answer"
      :cahblack -> "Question"
    end
  end

  def new(conn, _params) do
    changeset = Deck.change_card(%Card{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"card" => card_params}) do
    case Deck.create_card(card_params) do
      {:ok, card} ->
        conn
        |> put_flash(:info, "Card created successfully.")
        |> redirect(to: ~p"/cards/#{card}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    card = Deck.get_card!(id)
    render(conn, :show, card: card)
  end

  def edit(conn, %{"id" => id}) do
    card = Deck.get_card!(id)
    changeset = Deck.change_card(card)
    render(conn, :edit, card: card, changeset: changeset)
  end

  def update(conn, %{"id" => id, "card" => card_params}) do
    card = Deck.get_card!(id)

    case Deck.update_card(card, card_params) do
      {:ok, card} ->
        conn
        |> put_flash(:info, "Card updated successfully.")
        |> redirect(to: ~p"/cards/#{card}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, card: card, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    card = Deck.get_card!(id)
    {:ok, _card} = Deck.delete_card(card)

    conn
    |> put_flash(:info, "Card deleted successfully.")
    |> redirect(to: ~p"/cards")
  end
end
