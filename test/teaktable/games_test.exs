defmodule Teaktable.GamesTest do
  use Teaktable.DataCase

  alias Teaktable.Games

  describe "cah" do
    alias Teaktable.Games.CAH

    import Teaktable.GamesFixtures

    @invalid_attrs %{players: nil}

    test "list_cah/0 returns all cah" do
      cah = cah_fixture()
      assert Games.list_cah() == [cah]
    end

    test "get_cah!/1 returns the cah with given id" do
      cah = cah_fixture()
      assert Games.get_cah!(cah.id) == cah
    end

    test "create_cah/1 with valid data creates a cah" do
      valid_attrs = %{players: ["option1", "option2"]}

      assert {:ok, %CAH{} = cah} = Games.create_cah(valid_attrs)
      assert cah.players == ["option1", "option2"]
    end

    test "create_cah/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Games.create_cah(@invalid_attrs)
    end

    test "update_cah/2 with valid data updates the cah" do
      cah = cah_fixture()
      update_attrs = %{players: ["option1"]}

      assert {:ok, %CAH{} = cah} = Games.update_cah(cah, update_attrs)
      assert cah.players == ["option1"]
    end

    test "update_cah/2 with invalid data returns error changeset" do
      cah = cah_fixture()
      assert {:error, %Ecto.Changeset{}} = Games.update_cah(cah, @invalid_attrs)
      assert cah == Games.get_cah!(cah.id)
    end

    test "delete_cah/1 deletes the cah" do
      cah = cah_fixture()
      assert {:ok, %CAH{}} = Games.delete_cah(cah)
      assert_raise Ecto.NoResultsError, fn -> Games.get_cah!(cah.id) end
    end

    test "change_cah/1 returns a cah changeset" do
      cah = cah_fixture()
      assert %Ecto.Changeset{} = Games.change_cah(cah)
    end
  end
end
