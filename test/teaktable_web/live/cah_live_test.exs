defmodule TeaktableWeb.CAHLiveTest do
  use TeaktableWeb.ConnCase

  import Phoenix.LiveViewTest
  import Teaktable.GamesFixtures

  @create_attrs %{players: ["option1", "option2"]}
  @update_attrs %{players: ["option1"]}
  @invalid_attrs %{players: []}
  defp create_cah(_) do
    cah = cah_fixture()

    %{cah: cah}
  end

  describe "Index" do
    setup [:create_cah]

    test "lists all cah", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/cah")

      assert html =~ "Listing Cah"
    end

    test "saves new cah", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/cah")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Cah")
               |> render_click()
               |> follow_redirect(conn, ~p"/cah/new")

      assert render(form_live) =~ "New Cah"

      assert form_live
             |> form("#cah-form", cah: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#cah-form", cah: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/cah")

      html = render(index_live)
      assert html =~ "Cah created successfully"
    end

    test "updates cah in listing", %{conn: conn, cah: cah} do
      {:ok, index_live, _html} = live(conn, ~p"/cah")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#cah-#{cah.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/cah/#{cah}/edit")

      assert render(form_live) =~ "Edit Cah"

      assert form_live
             |> form("#cah-form", cah: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#cah-form", cah: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/cah")

      html = render(index_live)
      assert html =~ "Cah updated successfully"
    end

    test "deletes cah in listing", %{conn: conn, cah: cah} do
      {:ok, index_live, _html} = live(conn, ~p"/cah")

      assert index_live |> element("#cah-#{cah.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#cah-#{cah.id}")
    end
  end

  describe "Show" do
    setup [:create_cah]

    test "displays cah", %{conn: conn, cah: cah} do
      {:ok, _show_live, html} = live(conn, ~p"/cah/#{cah}")

      assert html =~ "Show Cah"
    end

    test "updates cah and returns to show", %{conn: conn, cah: cah} do
      {:ok, show_live, _html} = live(conn, ~p"/cah/#{cah}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/cah/#{cah}/edit?return_to=show")

      assert render(form_live) =~ "Edit Cah"

      assert form_live
             |> form("#cah-form", cah: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#cah-form", cah: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/cah/#{cah}")

      html = render(show_live)
      assert html =~ "Cah updated successfully"
    end
  end
end
