defmodule TeaktableWeb.MonikersLiveTest do
  use TeaktableWeb.ConnCase

  import Phoenix.LiveViewTest
  import Teaktable.GamesFixtures

  @create_attrs %{players: ["option1", "option2"]}
  @update_attrs %{players: ["option1"]}
  @invalid_attrs %{players: []}
  defp create_monikers(_) do
    monikers = monikers_fixture()

    %{monikers: monikers}
  end

  describe "Index" do
    setup [:create_monikers]

    test "lists all monikers", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/monikers")

      assert html =~ "Listing Monikers"
    end

    test "saves new monikers", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/monikers")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Monikers")
               |> render_click()
               |> follow_redirect(conn, ~p"/monikers/new")

      assert render(form_live) =~ "New Monikers"

      assert form_live
             |> form("#monikers-form", monikers: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#monikers-form", monikers: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/monikers")

      html = render(index_live)
      assert html =~ "Monikers created successfully"
    end

    test "updates monikers in listing", %{conn: conn, monikers: monikers} do
      {:ok, index_live, _html} = live(conn, ~p"/monikers")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#monikers-#{monikers.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/monikers/#{monikers}/edit")

      assert render(form_live) =~ "Edit Monikers"

      assert form_live
             |> form("#monikers-form", monikers: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#monikers-form", monikers: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/monikers")

      html = render(index_live)
      assert html =~ "Monikers updated successfully"
    end

    test "deletes monikers in listing", %{conn: conn, monikers: monikers} do
      {:ok, index_live, _html} = live(conn, ~p"/monikers")

      assert index_live |> element("#monikers-#{monikers.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#monikers-#{monikers.id}")
    end
  end

  describe "Show" do
    setup [:create_monikers]

    test "displays monikers", %{conn: conn, monikers: monikers} do
      {:ok, _show_live, html} = live(conn, ~p"/monikers/#{monikers}")

      assert html =~ "Show Monikers"
    end

    test "updates monikers and returns to show", %{conn: conn, monikers: monikers} do
      {:ok, show_live, _html} = live(conn, ~p"/monikers/#{monikers}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/monikers/#{monikers}/edit?return_to=show")

      assert render(form_live) =~ "Edit Monikers"

      assert form_live
             |> form("#monikers-form", monikers: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#monikers-form", monikers: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/monikers/#{monikers}")

      html = render(show_live)
      assert html =~ "Monikers updated successfully"
    end
  end
end
