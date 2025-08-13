defmodule TeaktableWeb.PageController do
  use TeaktableWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
