defmodule Teaktable.Games do
  @moduledoc """
  The Games context.
  """

  # alias Teaktable.Deck
  # alias Teaktable.Deck.Card
  # import Ecto.Query, warn: false
  # alias Teaktable.Repo

  defmodule Monikers do
    use Agent

    defstruct id: :monikers,
              current_player: nil,
              last_player: nil,
              current_team: :a,
              deck: [],
              total_pile: [],
              current_pile: [],
              state: :initial,
              teams: %{
                a: %{name: "Maws", players: [], score: 0},
                b: %{name: "Paws", players: [], score: 0}
              },
              timer: nil,
              timer_duration: 60,
              draft_count: 7,
              cards_to_pull: 10

    def start_link(_) do
      Agent.start_link(fn -> %Monikers{deck: Teaktable.Deck.monikers()} end, name: __MODULE__)
    end

    def get do
      Agent.get(__MODULE__, & &1)
    end

    def add_player(nickname, team) do
      game = get()

      # check to see if the player is already in the game, but disconnected - if so, inform their socket of the status of the game they're rejoining
      # if player is in the game and connected, return an error message

      if Enum.any?(players(), fn player -> player.name == nickname end) do
        player = Enum.find(players(), fn player -> player.name == nickname end)

        if player.connection do
          {:error, "Player with that nickname already exists in the game."}
        else
          # set that player's connection status to true, and return an :ok tuple with the current game state
          new_teams =
            Enum.reduce(game.teams, %{}, fn {team_key, team_data}, acc ->
              new_players =
                Enum.map(team_data.players, fn p ->
                  if p.name == nickname do
                    %{p | connection: true, ready: p.prior_readiness}
                  else
                    p
                  end
                end)

              Map.put(acc, team_key, %{team_data | players: new_players})
            end)

          Agent.update(__MODULE__, fn state ->
            %{state | teams: new_teams}
          end)

          TeaktableWeb.Endpoint.broadcast("monikers", "teams_change", %{
            teams: new_teams
          })

          {:ok, game}
        end
      else
        # otherwise, add player to the team
        new_team =
          Map.update!(game.teams[team], :players, fn players ->
            players ++ [%{name: nickname, connection: true, ready: false, prior_readiness: false}]
          end)

        new_teams = Map.put(game.teams, team, new_team)

        Agent.update(__MODULE__, fn state ->
          %{state | teams: new_teams}
        end)

        TeaktableWeb.Endpoint.broadcast("monikers", "teams_change", %{
          teams: new_teams
        })

        :ok
      end
    end

    def rename_team(team, new_name) do
      game = get()

      # rename the team and broadcast the change to the channel
      new_teams =
        Map.update!(game.teams, team, fn team_data ->
          %{team_data | name: new_name}
        end)

      Agent.update(__MODULE__, fn state -> %{state | teams: new_teams} end)

      TeaktableWeb.Endpoint.broadcast("monikers", "teams_change", %{
        teams: new_teams
      })
    end

    def disconnect(nickname) do
      game = get()

      # set that player's state within the team to disconnected, and broadcast this change to the channel.
      # disconnected players will be able to rejoin the game if they initialize with the same nickname.
      # disconnected players will have their turns skipped in the active phase, and their readiness state will not be pertinent to the drafting phase.
      IO.inspect(game.teams)
      IO.puts("Disconnecting player: #{nickname}")

      new_teams =
        Enum.reduce(game.teams, %{}, fn {team_key, team_data}, acc ->
          new_players =
            Enum.map(team_data.players, fn player ->
              if player.name == nickname do
                %{player | connection: false, ready: false, prior_readiness: player.ready}
              else
                player
              end
            end)

          Map.put(acc, team_key, %{team_data | players: new_players})
        end)

      Agent.update(__MODULE__, fn state ->
        %{state | teams: new_teams}
      end)

      TeaktableWeb.Endpoint.broadcast("monikers", "teams_change", %{
        teams: new_teams
      })
    end

    def draw_for_draft do
      game = get()
      drawn_cards = Enum.take_random(game.deck, game.cards_to_pull)
      new_deck = game.deck -- drawn_cards

      # remove drawn cards from the deck and return the drawn cards to the calling process
      Agent.update(__MODULE__, fn state -> %{state | deck: new_deck} end)
      drawn_cards
    end

    def return(cards) do
      Agent.update(__MODULE__, fn state -> %{state | deck: state.deck ++ cards} end)
    end

    def return_and_draw(cards) do
      new_cards = draw_for_draft()

      new_deck = get().deck ++ cards

      # add returned cards back to the deck
      Agent.update(__MODULE__, fn state -> %{state | deck: new_deck} end)
      new_cards
    end

    def ready(nickname, team, selected_cards, unselected_cards) do
      # Add player to the list of ready players, add their selected cards to the pile, and return their unselected cards to the draft deck

      Monikers.return(unselected_cards)

      new_pile = get().total_pile ++ selected_cards

      Agent.update(__MODULE__, fn state ->
        %{
          state
          | total_pile: new_pile,
            teams:
              Map.update!(state.teams, team, fn team_data ->
                %{
                  team_data
                  | players:
                      Enum.map(team_data.players, fn p ->
                        if p.name == nickname do
                          %{p | ready: true}
                        else
                          p
                        end
                      end)
                }
              end)
        }
      end)

      TeaktableWeb.Endpoint.broadcast("monikers", "ready_change", %{
        teams: get().teams
      })

      # check to see if all players are ready
      if Enum.count(ready_players()) == Enum.count(online_players()) do
        # if all players are ready, advance the game state to the next phase
        IO.puts("Game should advance to the playing phase now")

        Agent.update(__MODULE__, fn state ->
          %{state | state: :playing, current_pile: new_pile}
        end)

        TeaktableWeb.Endpoint.broadcast("monikers", "enter_play", %{})
        advance_player()
      end
    end

    def unready(nickname, team, picked_cards) do
      new_pile = get().total_pile -- picked_cards

      Agent.update(__MODULE__, fn state ->
        %{
          state
          | total_pile: new_pile,
            teams:
              Map.update!(state.teams, team, fn team_data ->
                %{
                  team_data
                  | players:
                      Enum.map(team_data.players, fn p ->
                        if p.name == nickname do
                          %{p | ready: false}
                        else
                          p
                        end
                      end)
                }
              end)
        }
      end)

      TeaktableWeb.Endpoint.broadcast("monikers", "ready_change", %{teams: get().teams})
    end

    def online_players do
      game = get()

      Enum.flat_map(game.teams, fn {_team, data} -> data.players end)
      |> Enum.filter(& &1.connection)
    end

    def ready_players do
      game = get()
      Enum.flat_map(game.teams, fn {_team, data} -> data.players end) |> Enum.filter(& &1.ready)
    end

    def advance_player do
      game = get()
      opposing_team = if game.current_team == :a, do: :b, else: :a

      new_game_state =
        if game.current_player == nil do
          # first turn of a game - set current player to first player on team A
          first_player = game.teams[:a].players |> Enum.sort() |> List.first()

          %{
            game
            | current_player: first_player,
              last_player: game.teams[:b].players |> Enum.sort() |> List.last(),
              state: :waiting_on_pickup
          }
        else
          opposing_players = Enum.sort(game.teams[opposing_team].players)

          next_player_index =
            Enum.find_index(opposing_players, fn player -> player == game.last_player end) + 1

          new_player =
            if next_player_index >= length(opposing_players) do
              List.first(opposing_players)
            else
              Enum.at(opposing_players, next_player_index)
            end

          %{
            game
            | current_player: new_player,
              last_player: game.current_player,
              state: :waiting_on_pickup
          }
        end

      Agent.update(__MODULE__, fn _ -> new_game_state end)

      TeaktableWeb.Endpoint.broadcast("monikers", "advance_turn", %{
        current_player: new_game_state.current_player
      })
    end

    defp players do
      game = get()
      game.teams[:a].players ++ game.teams[:b].players
    end
  end

  defmodule CAH do
  end
end
