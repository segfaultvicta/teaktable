defmodule TeaktableWeb.GameController do
  use Phoenix.Controller, formats: [:json]

  def obliterate_monikers_game(conn, _params) do
    {res, details} = Teaktable.Games.Monikers.obliterate()
    render(conn, :response, %{res: res, details: details})
  end

  def obliterate_cah_game(conn, _params) do
    {res, details} = Teaktable.Games.CAH.obliterate()
    render(conn, :response, %{res: res, details: details})
  end

  def monikers_adjust(conn, %{"cfg" => ["timer", val]}) do
    Teaktable.Games.Monikers.adjust_timer(String.to_integer(val))
    render(conn, :response, %{res: :ok, details: "config adjusted"})
  end

  def monikers_adjust(conn, %{"cfg" => ["select", val]}) do
    Teaktable.Games.Monikers.adjust_draft_count(String.to_integer(val))
    render(conn, :response, %{res: :ok, details: "config adjusted"})
  end

  def monikers_adjust(conn, %{"cfg" => ["draw", val]}) do
    Teaktable.Games.Monikers.adjust_cards_to_pull(String.to_integer(val))
    render(conn, :response, %{res: :ok, details: "config adjusted"})
  end

  def monikers_adjust(conn, params) do
    IO.puts("Unhandled Monikers configuration adjustment: #{inspect(params)}")

    render(conn, :response, %{
      res: :error,
      details: "unrecognised config parameters #{inspect(params)}"
    })
  end

  def cah_adjust(conn, %{"cfg" => ["handsize", val]}) do
    Teaktable.Games.CAH.adjust_hand_size(String.to_integer(val))
    render(conn, :response, %{res: :ok, details: "config adjusted"})
  end

  def cah_adjust(conn, params) do
    IO.puts("Unhandled CAH configuration adjustment: #{inspect(params)}")

    render(conn, :response, %{
      res: :error,
      details: "unrecognised config parameters #{inspect(params)}"
    })
  end
end
