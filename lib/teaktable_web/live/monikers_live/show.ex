defmodule TeaktableWeb.MonikersLive.Show do
  use TeaktableWeb, :live_view

  alias Teaktable.Games.Monikers

  @impl true
  def mount(_params, _session, socket) do
    # we're going to want to get the Monikers *channel* socket here, so that we can push to and recieve from it in the liveview context. TODO
    TeaktableWeb.Endpoint.subscribe("monikers")

    {:ok,
     socket
     |> assign(:page_title, "Monikers")
     |> assign(:available_cards, [])
     |> assign(:picked_cards, [])
     |> assign(:current_player, nil)
     |> assign(:current_card, nil)
     |> assign(:cards_remaining, nil)
     |> assign(:cards_in_discard, nil)
     |> assign(:timer_display, nil)
     |> assign(:state, :initialized)
     |> assign(:readiness, false)
     |> assign(:cards_drawn, false)
     |> assign(:teams, Monikers.get().teams)
     |> assign(:nickname, "")
     |> assign(:chosen_team, nil)
     |> assign(:team_open_for_renaming, nil)}
  end

  @impl true
  def handle_event("change_nickname", %{"nickname" => nickname}, socket) do
    {:noreply, assign(socket, :nickname, nickname)}
  end

  @impl true
  def handle_event("select_team", %{"team" => team}, socket) do
    team = String.to_atom(team)

    if team == socket.assigns.chosen_team do
      {:noreply, assign(socket, :chosen_team, nil)}
    else
      {:noreply, assign(socket, :chosen_team, team)}
    end
  end

  def handle_event(
        "rename_team",
        %{"team" => team, "value" => new_name, "key" => "Enter"},
        socket
      ) do
    internal_rename(team, new_name, socket)
  end

  def handle_event("rename_team", %{"team" => team, "value" => new_name}, socket) do
    internal_rename(team, new_name, socket)
  end

  def handle_event("open_team_for_renaming", %{"team" => team}, socket) do
    team = String.to_atom(team)

    if socket.assigns.chosen_team == team do
      {:noreply, assign(socket, :team_open_for_renaming, team)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("initialize", _params, socket) do
    nickname = socket.assigns.nickname
    chosen_team = socket.assigns.chosen_team

    case Monikers.add_player(nickname, chosen_team) do
      :ok ->
        {:noreply, socket |> assign(:state, :drafting)}

      {:ok, game} ->
        liveview_state =
          case game.state do
            :initial -> :drafting
            :playing -> :playing
            :waiting_on_pickup -> :playing
            :complete -> :complete
            _ -> :initialized
          end

        previous_team =
          game.teams
          |> Enum.find(fn {_team, data} ->
            Enum.any?(data.players, fn p -> p.name == nickname end)
          end)
          |> elem(0)

        {:noreply,
         socket
         |> assign(:nickname, nickname)
         |> assign(:chosen_team, previous_team)
         |> assign(:teams, game.teams)
         |> put_flash(:info, "Reconnected!")
         |> assign(:state, liveview_state)}

      {:error, message} ->
        {:noreply,
         socket
         |> put_flash(:error, message)
         |> assign(:state, :initialized)
         |> assign(:nickname, "")}
    end
  end

  def handle_event("join_as_spectator", _params, socket) do
    nickname = socket.assigns.nickname
    chosen_team = :spectators

    case Monikers.add_player(nickname, chosen_team) do
      :ok ->
        {:noreply, socket |> assign(:state, :observing)}

      {:error, message} ->
        {:noreply, socket |> assign(:state, :initialized) |> put_flash(:error, message)}

      _ ->
        {:noreply,
         socket
         |> assign(:state, :initialized)
         |> put_flash(:error, "Error joining game as audience.")}
    end
  end

  def handle_event("reconnect", params, socket) do
    nickname = params["nickname"]

    previous_team =
      socket.assigns.teams
      |> Enum.find(fn {_team, data} ->
        Enum.any?(data.players, fn p -> p.name == nickname end)
      end)
      |> elem(0)

    case Monikers.add_player(nickname, previous_team) do
      {:ok, game} ->
        liveview_state =
          case game.state do
            :initial -> :drafting
            :playing -> :playing
            :waiting_on_pickup -> :playing
            _ -> :initialized
          end

        {:noreply,
         socket
         |> assign(:nickname, nickname)
         |> assign(:chosen_team, previous_team)
         |> assign(:teams, game.teams)
         |> assign(:state, liveview_state)
         |> assign(:current_player, game.current_player)
         |> put_flash(:info, "Reconnected!")}

      {:error, message} ->
        {:noreply,
         socket
         |> put_flash(:error, message)
         |> assign(:state, :initialized)
         |> assign(:nickname, "")}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Something truly cursed happened reconnecting player #{nickname}.")
         |> assign(:state, :initialized)
         |> assign(:nickname, "")}
    end
  end

  def handle_event("draw_cards", _params, socket) do
    cards = Monikers.draw_for_draft()
    {:noreply, socket |> assign(:available_cards, cards) |> assign(:cards_drawn, true)}
  end

  def handle_event("return_and_draw", _params, socket) do
    cards = Monikers.return_and_draw(socket.assigns.available_cards)
    {:noreply, assign(socket, :available_cards, cards)}
  end

  def handle_event("pick_card", %{"card" => card_id}, socket) do
    card =
      Enum.find(socket.assigns.available_cards, fn c -> c.id == String.to_integer(card_id) end)

    if card do
      new_picked_cards = socket.assigns.picked_cards ++ [card]

      new_available_cards =
        Enum.reject(socket.assigns.available_cards, fn c -> c.id == card.id end)

      {:noreply,
       socket
       |> assign(:picked_cards, new_picked_cards)
       |> assign(:available_cards, new_available_cards)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("unpick_card", %{"card" => card_id}, socket) do
    card = Enum.find(socket.assigns.picked_cards, fn c -> c.id == String.to_integer(card_id) end)

    if card do
      new_available_cards = socket.assigns.available_cards ++ [card]
      new_picked_cards = Enum.reject(socket.assigns.picked_cards, fn c -> c.id == card.id end)

      {:noreply,
       socket
       |> assign(:picked_cards, new_picked_cards)
       |> assign(:available_cards, new_available_cards)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("ready", _params, socket) do
    Monikers.ready(
      socket.assigns.nickname,
      socket.assigns.chosen_team,
      socket.assigns.picked_cards,
      socket.assigns.available_cards
    )

    {:noreply,
     socket
     |> assign(:readiness, true)
     |> assign(:available_cards, [])}
  end

  def handle_event("unready", _params, socket) do
    Monikers.unready(
      socket.assigns.nickname,
      socket.assigns.chosen_team,
      socket.assigns.picked_cards
    )

    {:noreply, socket |> assign(:readiness, false) |> assign(:cards_drawn, false)}
  end

  def handle_event("first_pickup", _params, socket) do
    {current_card, cards_remaining, cards_in_discard} = Monikers.draw_from_pile()

    Monikers.begin_timer()

    :timer.send_after(1000, :tick)

    {:noreply,
     socket
     |> assign(:current_card, current_card)
     |> assign(:cards_remaining, cards_remaining)
     |> assign(:cards_in_discard, cards_in_discard)}
  end

  def handle_event("skip", %{"card" => card_id}, socket) do
    Monikers.discard(card_id)

    {current_card, cards_remaining, cards_in_discard} = Monikers.draw_from_pile()

    {:noreply,
     socket
     |> assign(:current_card, current_card)
     |> assign(:cards_remaining, cards_remaining)
     |> assign(:cards_in_discard, cards_in_discard)}
  end

  def handle_event("award", %{"card" => card_id}, socket) do
    Monikers.award(socket.assigns.chosen_team, card_id)

    {current_card, cards_remaining, cards_in_discard} = Monikers.draw_from_pile()

    if current_card == nil do
      Monikers.handle_EOR()
    else
      # round continues
      {:noreply,
       socket
       |> assign(:current_card, current_card)
       |> assign(:cards_remaining, cards_remaining)
       |> assign(:cards_in_discard, cards_in_discard)}
    end
  end

  @impl true
  def handle_event(event, params, socket) do
    IO.puts("Unhandled event in MonikersLive.Show: #{event} with params: #{inspect(params)}")
    {:noreply, socket}
  end

  def handle_info(:tick, socket) do
    case Monikers.tick() do
      :ok ->
        :timer.send_after(1000, :tick)

      :zero ->
        Monikers.discard(socket.assigns.current_card.id)
        :timer.send_after(500, :tick)

      _ ->
        nil
    end

    {:noreply, socket}
  end

  def handle_info(%{event: "timer_update", payload: %{timer: new_timer}}, socket) do
    {:noreply, assign(socket, :timer_display, new_timer)}
  end

  def handle_info(%{event: "teams_change", payload: %{teams: teams}}, socket) do
    {:noreply, assign(socket, :teams, teams)}
  end

  def handle_info(%{event: "score_update", payload: %{teams: teams}}, socket) do
    {:noreply, assign(socket, :teams, teams)}
  end

  def handle_info(%{event: "ready_change", payload: %{teams: teams}}, socket) do
    {:noreply, assign(socket, :teams, teams)}
  end

  def handle_info(%{event: "enter_play", payload: _payload}, socket) do
    {:noreply, assign(socket, :state, :playing)}
  end

  def handle_info(%{event: "advance_turn", payload: %{current_player: current_player}}, socket) do
    # this will have to check if *we're* the current player; if we're not, we don't have to do anything
    {:noreply, assign(socket, :current_player, current_player)}
  end

  def handle_info(%{event: "round_end", payload: %{new_round: new_round}}, socket) do
    {:noreply,
     socket |> assign(:timer_display, nil) |> put_flash(:info, "ENTERING ROUND #{new_round}!")}
  end

  def handle_info(%{event: "game_end", payload: _payload}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "GAME OVER! CELEBRATE THE VICTOR OR FACE TEAKWOOD'S WRATH")
     |> assign(:timer_display, nil)
     |> assign(:state, :complete)}
  end

  def handle_info(%{event: "restart", payload: _payload}, socket) do
    {:noreply,
     socket
     |> assign(:available_cards, [])
     |> assign(:picked_cards, [])
     |> assign(:current_player, nil)
     |> assign(:current_card, nil)
     |> assign(:state, :initialized)
     |> assign(:readiness, false)
     |> assign(:cards_drawn, false)
     |> assign(:teams, Monikers.get().teams)
     |> assign(:chosen_team, nil)
     |> assign(:team_open_for_renaming, nil)
     |> put_flash(:info, "Game was restarted via sorcery.")}
  end

  @impl true
  def handle_info(payload, socket) do
    IO.puts("Unhandled info payload in MonikersLive.Show: #{inspect(payload)}")

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    # If we're terminating a session during the drafting phase, return all the currently-held cards (both selected and not) to the deck
    if socket.assigns.state == :drafting do
      Monikers.return(socket.assigns.available_cards ++ socket.assigns.picked_cards)
    end

    # Tell the Monikers game that this player has disconnected, if they've already initialized
    if socket.assigns.state != :initialized do
      Monikers.disconnect(socket.assigns.nickname)
    end

    TeaktableWeb.Endpoint.unsubscribe("monikers")
    :ok
  end

  defp internal_rename(team, new_name, socket) do
    team = String.to_atom(team)

    opposing_team_name =
      if team == :a do
        socket.assigns.teams[:b].name
      else
        socket.assigns.teams[:a].name
      end

    if new_name != "" && new_name != opposing_team_name do
      Monikers.rename_team(team, new_name)
      {:noreply, assign(socket, :team_open_for_renaming, nil)}
    else
      {:noreply,
       assign(socket, :team_open_for_renaming, nil)
       |> put_flash(
         :error,
         "Team name cannot be empty, and cannot be the same as that of the opposing team."
       )}
    end
  end

  defp join_valid?(nickname, chosen_team) do
    if nickname != "" and (chosen_team == :a or chosen_team == :b) and
         Monikers.game_phase() not in [:playing, :waiting_for_pickup] do
      :as_player
    else
      if nickname != "" do
        :as_spectator
      else
        false
      end
    end
  end
end
