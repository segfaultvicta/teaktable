defmodule TeaktableWeb.CAHLive.Show do
  use TeaktableWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Beep
      </.header>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "CAH Placeholder will be replaced with something funny")}
  end
end
