defmodule TeaktableWeb.CAHLive.Show do
  use TeaktableWeb, :live_view

  alias Teaktable.Games.CAH

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      {:ok, %{name: name, current_active: current_active}} = CAH.add_player(CAH.playername())
      TeaktableWeb.Endpoint.subscribe("cah")

      {:ok,
       socket
       |> assign(:page_title, CAH.name())
       |> assign(:current_active, current_active)
       |> assign(:name, name)
       |> assign(:name_open_for_edit, false)
       |> assign(:selected_black_card, nil)
       |> assign(:available_black_cards, nil)
       |> assign(:submitted_white_cards, [])
       |> assign(:selected_white_cards, [])
       |> assign(:players, CAH.players())
       |> assign(:hand, CAH.white(CAH.hand_size()))
       |> assign(:waiting_for_submissions, false)}
    else
      {:ok,
       socket
       |> assign(:page_title, "CAH")
       |> assign(:current_active, nil)
       |> assign(:name, "")
       |> assign(:name_open_for_edit, false)
       |> assign(:hand, [])
       |> assign(:selected_black_card, nil)
       |> assign(:available_black_cards, nil)
       |> assign(:submitted_white_cards, [])
       |> assign(:selected_white_cards, [])
       |> assign(:waiting_for_submissions, false)
       |> assign(:players, [])}
    end
  end

  def handle_event("change_nickname", %{"value" => name, "key" => "Enter"}, socket) do
    CAH.change_nickname(socket.assigns.name, name)
    {:noreply, assign(socket, :name, name) |> assign(:name_open_for_edit, false)}
  end

  @impl true
  def handle_event("change_nickname", %{"value" => name}, socket) do
    CAH.change_nickname(socket.assigns.name, name)
    {:noreply, assign(socket, :name, name) |> assign(:name_open_for_edit, false)}
  end

  def handle_event("open_name_for_edit", _params, socket) do
    {:noreply, assign(socket, :name_open_for_edit, true)}
  end

  def handle_event("claim", _params, socket) do
    CAH.begin_game(socket.assigns.name)
    {:noreply, socket}
  end

  def handle_event("submit_white_cards", _params, socket) do
    CAH.submit_white(socket.assigns.name, socket.assigns.selected_white_cards)
    new_hand = socket.assigns.hand -- socket.assigns.selected_white_cards

    diff = CAH.hand_size() - length(new_hand)
    cards = CAH.white(diff)
    {:noreply, socket |> assign(:hand, new_hand ++ cards) |> assign(:selected_white_cards, [])}
  end

  def handle_event("draw_black_cards", _params, socket) do
    {:noreply, socket |> assign(:available_black_cards, CAH.black(CAH.hand_size()))}
  end

  def handle_event("submit_black_card", %{"card" => card}, socket) do
    CAH.submit_black(card)

    {:noreply,
     socket
     |> assign(:selected_black_card, nil)
     |> assign(:available_black_cards, nil)
     |> assign(:waiting_for_submissions, true)}
  end

  def handle_event("toggle_card", %{"card" => card}, socket) do
    if Enum.member?(socket.assigns.selected_white_cards, card) do
      {:noreply,
       socket |> assign(:selected_white_cards, socket.assigns.selected_white_cards -- [card])}
    else
      {:noreply,
       socket |> assign(:selected_white_cards, socket.assigns.selected_white_cards ++ [card])}
    end
  end

  def handle_event("discard", %{"card" => card}, socket) do
    # this might break if we discard a white card that ISN'T selected? we'll find out together!
    new_card = CAH.white(1)
    CAH.return(card)

    {:noreply,
     socket
     |> assign(:hand, (socket.assigns.hand -- [card]) ++ new_card)
     |> assign(:selected_white_cards, socket.assigns.selected_white_cards -- [card])}
  end

  def handle_event("choose_submitted_white_cards", %{"from" => from}, socket) do
    CAH.choose_submitted_white_cards(from)

    {:noreply,
     socket |> assign(:submitted_white_cards, []) |> assign(:waiting_for_submissions, false)}
  end

  @impl true
  def handle_event(event, params, socket) do
    IO.puts("Unhandled event in CAHLive.Show: #{event} with params: #{inspect(params)}")
    {:noreply, socket}
  end

  def handle_info(%{event: "players", payload: %{data: players}}, socket) do
    {:noreply, assign(socket, :players, players)}
  end

  def handle_info(%{event: "restart", payload: _payload}, socket) do
    {:noreply,
     socket
     |> assign(:players, [])
     |> assign(:hand, [])
     |> put_flash(:info, "Game was restarted via API sorcery.")}
  end

  def handle_info(%{event: "black", payload: %{card: card}}, socket) do
    # only respond to Black events if you're the inactive player
    if socket.assigns.name == socket.assigns.current_active do
      {:noreply, socket}
    else
      {:noreply, socket |> assign(:selected_black_card, card)}
    end
  end

  def handle_info(%{event: "white", payload: %{cards: cards, from: name}}, socket) do
    # only respond to White events if you're the active player
    if socket.assigns.name == socket.assigns.current_active do
      {:noreply,
       socket
       |> assign(
         :submitted_white_cards,
         [%{cards: cards, from: name} | socket.assigns.submitted_white_cards]
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{event: "new_round", payload: %{current_active: current_active}}, socket) do
    {:noreply,
     socket
     |> assign(:selected_black_card, nil)
     |> assign(:submitted_white_cards, [])
     |> assign(:current_active, current_active)}
  end

  @impl true
  def handle_info(payload, socket) do
    IO.puts("Unhandled info payload in CAHLive.Show: #{inspect(payload)}")

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    CAH.disconnect(socket.assigns.name, socket.assigns.hand)
    TeaktableWeb.Endpoint.unsubscribe("cah")
    :ok
  end
end
