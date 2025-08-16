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
              current_team: :b,
              deck: [],
              total_pile: [],
              draw_pile: [],
              discard_pile: [],
              state: :initial,
              round: 0,
              teams: %{
                a: %{name: "Maws", players: [], score: 0},
                b: %{name: "Paws", players: [], score: 0},
                spectators: %{name: "Spectators", players: [], score: nil}
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

    def game_phase do
      get().state
    end

    def obliterate do
      Agent.update(__MODULE__, fn keepDefault ->
        %Monikers{
          deck: Teaktable.Deck.monikers(),
          timer_duration: keepDefault.timer_duration,
          draft_count: keepDefault.draft_count,
          cards_to_pull: keepDefault.cards_to_pull
        }
      end)

      TeaktableWeb.Endpoint.broadcast("monikers", "restart", %{})

      {:ok, "monikers game has been restarted"}
    end

    def adjust_timer(val) do
      Agent.update(__MODULE__, fn state -> %{state | timer_duration: val} end)
    end

    def adjust_draft_count(val) do
      Agent.update(__MODULE__, fn state -> %{state | draft_count: val} end)
    end

    def adjust_cards_to_pull(val) do
      Agent.update(__MODULE__, fn state -> %{state | cards_to_pull: val} end)
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

        Agent.update(__MODULE__, fn state ->
          %{state | state: :playing, draw_pile: new_pile}
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
      (game.teams[:a].players ++ game.teams[:b].players) |> Enum.filter(& &1.connection)
    end

    def ready_players do
      game = get()
      (game.teams[:a].players ++ game.teams[:b].players) |> Enum.filter(& &1.ready)
    end

    def advance_player do
      game = get()
      opposing_team = if game.current_team == :a, do: :b, else: :a

      draw_pile = Enum.shuffle(game.draw_pile ++ game.discard_pile)

      new_game_state =
        if game.current_player == nil do
          # first turn of a game - set current player to first player on team A
          first_player = game.teams[:a].players |> Enum.sort() |> List.first()

          %{
            game
            | current_player: first_player,
              last_player: game.teams[:b].players |> Enum.sort() |> List.last(),
              current_team: opposing_team,
              draw_pile: draw_pile,
              round: 1,
              discard_pile: []
          }
        else
          opposing_players = Enum.sort(game.teams[opposing_team].players)

          player_index =
            Enum.find_index(opposing_players, fn player -> player == game.last_player end)

          # this is a kludge to get around a crash when the active player rejoins mid-countdown
          # and should be fixed later to properly handle the error state
          next_player_index =
            if player_index == nil do
              IO.puts("ALERT ALERT THE KLUDGE IS HAPPENING THE KLUDGE IS HAPPENING")
              0
            else
              player_index + 1
            end

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
              current_team: opposing_team,
              draw_pile: draw_pile,
              discard_pile: []
          }
        end

      Agent.update(__MODULE__, fn _ -> %{new_game_state | state: :waiting_on_pickup} end)

      TeaktableWeb.Endpoint.broadcast("monikers", "advance_turn", %{
        current_player: new_game_state.current_player
      })
    end

    def draw_from_pile do
      # check to see if there are cards remaining in the draw pile. if there are not, the discard pile becomes the new draw pile
      {draw_pile, discard_pile} =
        if Enum.count(get().draw_pile) > 0 do
          {get().draw_pile, get().discard_pile}
        else
          {get().discard_pile, []}
        end

      # if draw pile is still empty now, it means the discard pile was empty too, so panic and return nil

      if Enum.count(draw_pile) == 0 do
        {nil, 0, 0}
      else
        # take a card from the draw pile, return that card, and the number of cards currently in the remaining draw pile after that point, and in the discard pile
        [card | rest] = draw_pile

        Agent.update(__MODULE__, fn state ->
          %{state | draw_pile: rest, discard_pile: discard_pile}
        end)

        # maybe I want to broadcast the information about the discard and draw pile cardinality here? maybe i do not? it is a mysteryyyyyyyyy

        {card, Enum.count(rest), Enum.count(discard_pile)}
      end
    end

    def begin_timer do
      duration = get().timer_duration

      Agent.update(__MODULE__, fn state ->
        %{state | timer: duration, state: :countdown}
      end)
    end

    def tick do
      game = get()

      if game.timer != nil do
        new_timer = game.timer - 1

        if new_timer == 0 do
          # timer hits 0, end of current player's turn, advance player
          Agent.update(__MODULE__, fn state -> %{state | timer: nil} end)
          TeaktableWeb.Endpoint.broadcast("monikers", "timer_update", %{timer: nil})
          :zero
        else
          Agent.update(__MODULE__, fn state -> %{state | timer: new_timer} end)
          TeaktableWeb.Endpoint.broadcast("monikers", "timer_update", %{timer: new_timer})
          :ok
        end
      else
        advance_player()
        nil
      end
    end

    def discard(card_id) do
      # put card_id in the discard pile
      card = Teaktable.Deck.get_card!(card_id)
      discard_pile = get().discard_pile ++ [card]
      Agent.update(__MODULE__, fn state -> %{state | discard_pile: discard_pile} end)
    end

    def award(chosen_team, card_id) do
      # let instance of the card evaporate but award its card.score number of points to the relevant team
      card_score = Teaktable.Deck.get_card!(card_id).score
      team = Map.update!(get().teams[chosen_team], :score, fn score -> score + card_score end)
      new_teams = Map.update!(get().teams, chosen_team, fn _ -> team end)
      Agent.update(__MODULE__, fn state -> %{state | teams: new_teams} end)

      TeaktableWeb.Endpoint.broadcast("monikers", "score_update", %{teams: new_teams})
    end

    def handle_EOR do
      game = get()

      if game.round == 3 do
        # signal in some capacity that the game is over, celebrate the winner gloriously
        Agent.update(__MODULE__, fn state -> %{state | state: :complete, timer: nil} end)
        TeaktableWeb.Endpoint.broadcast("monikers", "game_end", %{})
      else
        Agent.update(__MODULE__, fn state ->
          %{
            state
            | discard_pile: [],
              draw_pile: game.total_pile,
              timer: nil,
              round: game.round + 1
          }
        end)

        TeaktableWeb.Endpoint.broadcast("monikers", "round_end", %{new_round: game.round + 1})
      end
    end

    defp players do
      game = get()
      game.teams[:a].players ++ game.teams[:b].players
    end
  end

  defmodule CAH do
    use Agent

    defstruct id: :cah,
              black: [],
              white: [],
              players: [],
              current_active: nil,
              hand_size: 9

    def start_link(_) do
      Agent.start_link(
        fn ->
          %CAH{black: Teaktable.Deck.cahblack(), white: Teaktable.Deck.cahwhite()}
        end,
        name: __MODULE__
      )
    end

    def obliterate do
      Agent.update(__MODULE__, fn keepDefault ->
        %CAH{
          black: Teaktable.Deck.cahblack(),
          white: Teaktable.Deck.cahwhite(),
          hand_size: keepDefault.hand_size
        }
      end)

      TeaktableWeb.Endpoint.broadcast("cah", "restart", %{})

      {:ok, "cah game has been restarted"}
    end

    def get do
      Agent.get(__MODULE__, & &1)
    end

    def hand_size do
      get().hand_size
    end

    def adjust_hand_size(val) do
      Agent.update(__MODULE__, fn state -> %{state | hand_size: val} end)
    end

    def begin_game(first_player) do
      Agent.update(__MODULE__, fn state -> %{state | current_active: first_player} end)

      TeaktableWeb.Endpoint.broadcast("cah", "new_round", %{current_active: first_player})
    end

    def change_nickname(old_name, new_name) do
      IO.puts("changing nick #{old_name} to #{new_name}")

      new_players =
        players()
        |> Enum.map(fn p ->
          if p.name == old_name do
            %{p | name: new_name}
          else
            p
          end
        end)

      Agent.update(__MODULE__, fn state ->
        %{
          state
          | players: new_players
        }
      end)

      TeaktableWeb.Endpoint.broadcast("cah", "players", %{data: new_players})
    end

    def advance_player do
      players = players()
      idx = players |> Enum.find_index(&(&1.name == get().current_active))

      next_idx =
        if idx + 1 >= length(players) do
          0
        else
          idx + 1
        end

      Agent.update(__MODULE__, fn state ->
        %{state | current_active: Enum.at(players, next_idx).name}
      end)

      TeaktableWeb.Endpoint.broadcast("cah", "new_round", %{
        current_active: Enum.at(players, next_idx).name
      })
    end

    def players do
      get().players |> Enum.sort(&(&1.order < &2.order))
    end

    def add_player(name) do
      players = players()

      if not Enum.any?(players, fn player -> player.name == name end) do
        Agent.update(__MODULE__, fn state ->
          %{
            state
            | players: [%{name: name, score: 0, order: :rand.uniform(1000)} | players]
          }
        end)

        TeaktableWeb.Endpoint.broadcast("cah", "players", %{data: players()})
        {:ok, %{name: name, current_active: get().current_active}}
      else
        add_player(CAH.playername())
      end
    end

    def disconnect(name, cards) do
      return(cards)

      # need to handle case where the active player is disconnecting
      if get().current_active == name do
        players = players()
        idx = players |> Enum.find_index(&(&1.name == name))

        next_idx =
          if idx + 1 >= length(players) do
            0
          else
            idx + 1
          end

        Agent.update(__MODULE__, fn state ->
          %{
            state
            | current_active: Enum.at(players, next_idx).name,
              players: players |> Enum.reject(&(&1.name == name))
          }
        end)

        TeaktableWeb.Endpoint.broadcast("cah", "players", %{data: get().players})

        :ok
      else
        new_players = get().players |> Enum.reject(&(&1.name == name))

        Agent.update(__MODULE__, fn state ->
          %{state | players: new_players}
        end)

        TeaktableWeb.Endpoint.broadcast("cah", "players", %{data: get().players})

        :ok
      end
    end

    def return(cards) when is_list(cards) do
      Agent.update(__MODULE__, fn state -> %{state | white: state.white ++ cards} end)
    end

    def return(card) when is_binary(card) do
      Agent.update(__MODULE__, fn state -> %{state | white: [card | state.white]} end)
    end

    def white(num) do
      # remove N white cards from the deck and give them to the user
      cards = Enum.take_random(get().white, num)

      Agent.update(__MODULE__, fn state -> %{state | white: state.white -- cards} end)

      cards
    end

    def black(num) do
      # display ten black cards to the user, but do not actually *remove* them from the black deck
      Enum.take_random(get().black, num)
    end

    def submit_black(card) do
      TeaktableWeb.Endpoint.broadcast("cah", "black", %{card: card})
    end

    def submit_white(name, cards) do
      return(cards)
      TeaktableWeb.Endpoint.broadcast("cah", "white", %{cards: cards, from: name})
    end

    def choose_submitted_white_cards(from) do
      # these cards have already been submitted back to the deck - they can evaporate at this point
      score(from)
      advance_player()
    end

    def score(name) do
      # increment named player's score by one
      players = get().players

      new_players =
        Enum.map(players, fn p ->
          if p.name == name do
            %{p | score: p.score + 1}
          else
            p
          end
        end)

      Agent.update(__MODULE__, fn state ->
        %{
          state
          | players: new_players
        }
      end)

      TeaktableWeb.Endpoint.broadcast("cah", "players", %{data: new_players})
    end

    def playername do
      adjective =
        ~w(aggressive agreeable ambidextrous ambitious brave breezy calm content dapper delightful eager easy faithful frabjous friendly gentle grateful happy helpful irate irenic jolly kind lovely lively neighborly nice obedient opulent odd polite proud punctual quirky quiet rad rambunctious shy silly towering unctuous victorious vorpal witty wonderful xeric xenial yowling zealous)

      noun =
        ~w(aardvark antelope armadillo alligator aquerne axolotl badger beaver booby blobfish brontosaur capybara cheetah crocodile crow cuttlefish dingo dragon ermine emu eel ferret falcon fox gerbil heron impala ibex jackalope jellyfish koala leopard lion lobster lynx matamata meerkat narwhal ocelot octopus otter pangolin panther puffin quetzal ringtail salamander snek squirrel tiger titmouse tortoise unicorn vulture wolf werewolf xoloitzcuintle yak zebra)

      "#{String.capitalize(Enum.take_random(adjective, 1) |> List.first())} #{String.capitalize(Enum.take_random(noun, 1) |> List.first())}"
    end

    def name do
      c =
        ~w(caterpillars cryptographers corals cannons chilis clouds curves chomps crowns cabooses crabs coats crows calves carpets coffeecups continents caravans curses cameras committees cubes cats cakes cars crimes cliffs clowns crowds clamps crayons crunches chains crepes coblyns crystals)

      a =
        ~w(admit adjust alter accomplish abate accept affect accelerate advise acquire access absorb acclaim address accommodate accumulate allow arbitrate awaken accuse abandon admire adore amuse analyze anticipate avoid)

      h =
        ~w(humidity hierarchy homosexuality holidays hospitality horseradish hermeneutics hyperactivity haberdashery hydrophobia horseplay hallucination homoeroticism heartbreak hullaballoos highways heroism honesty haddock hydration heresy hedonism hypnotism harmony)

      "#{String.capitalize(Enum.take_random(c, 1) |> List.first())} #{String.capitalize(Enum.take_random(a, 1) |> List.first())} #{String.capitalize(Enum.take_random(h, 1) |> List.first())}"
    end
  end
end
