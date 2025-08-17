defmodule TeaktableWeb.Router do
  use TeaktableWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TeaktableWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TeaktableWeb do
    pipe_through :browser

    get "/", PageController, :home

    # get "/cards/monikers", CardController, :monikers
    # get "/cards/answer", CardController, :cahwhite
    # get "/cards/question", CardController, :cahblack
    # resources "/cards", CardController
    live "/cards", CardLive.Index, :index
    live "/cards/monikers", CardLive.Index, :monikers
    live "/cards/answer", CardLive.Index, :cahwhite
    live "/cards/question", CardLive.Index, :cahblack
    live "/cards/new", CardLive.Form, :new
    live "/cards/:id/edit", CardLive.Form, :edit
    live "/cah", CAHLive.Show
    live "/monikers", MonikersLive.Show
  end

  # Other scopes may use custom stacks.
  scope "/api", TeaktableWeb do
    pipe_through :api
    get "/monikers/obliterate", GameController, :obliterate_monikers_game
    get "/monikers/*cfg", GameController, :monikers_adjust
    get "/cah/obliterate", GameController, :obliterate_cah_game
    get "/cah/*cfg", GameController, :cah_adjust
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:teaktable, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TeaktableWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
