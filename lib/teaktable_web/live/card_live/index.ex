defmodule TeaktableWeb.CardLive.Index do
  use TeaktableWeb, :live_view

  alias Teaktable.Deck

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        <:flex_middle>
          <div class="flex flex-row w-1/3 justify-between text-lg font-semibold underline pt-10">
            <.link navigate={~p"/cards/monikers"}>Monikers</.link>
            <.link navigate={~p"/cards/question"}>Question</.link>
            <.link navigate={~p"/cards/answer"}>Answer</.link>
          </div>
        </:flex_middle>

        <:actions></:actions>
      </.header>

      <div
        id="new_card_input"
        class="flex flex-col items-center justify-center text-lg mt-5 mb-16"
      >
        <%= case @live_action do %>
          <% :monikers -> %>
            <h3 class="text-2xl">New Card</h3>
            <div>
              <.form for={@form} id="card-form" phx-submit="new_card" phx-change="validate">
                <.input field={@form[:title]} type="text" label="Title" />
                <.input field={@form[:description]} type="textarea" label="Text" />
                <.input
                  field={@form[:score]}
                  type="number"
                  min="1"
                  max="5"
                  label="Score"
                />
                <footer>
                  <.button class="btn btn-primary">Add To Deck</.button>
                </footer>
              </.form>
            </div>
          <% :cahwhite -> %>
            <h3 class="text-2xl">New Card</h3>
            <div>
              <.form for={@form} id="card_form" phx-submit="new_card" phx-change="validate">
                <.input field={@form[:description]} type="textarea" label="Text" />
                <.button class="btn btn-primary">Add To Deck</.button>
              </.form>
            </div>
          <% :cahblack -> %>
            <div>
              <h3 class="text-2xl">New Card</h3>
              <.form for={@form} id="card-form" phx-submit="new_card" phx-change="validate">
                <.input field={@form[:description]} type="textarea" label="Text" />
                <.button class="btn btn-primary">Add To Deck</.button>
              </.form>
            </div>
          <% :index -> %>
            <div></div>
        <% end %>
      </div>

      <div
        id="deck"
        class="grid grid-flow-row lg:grid-cols-6 md:grid-cols-4 sm:grid-cols-1 gap-10"
        phx-update="stream"
      >
        <%= for {id, card} <- @streams.cards do %>
          <.form for={@form} id={"edit-card-#{id}"} phx-submit="save" phx-update="stream">
            <div id={id} class={~w(card bg-neutral text-neutral-content card-lg)}>
              <div class="card-body items-center text-center">
                <%= if card.title != nil do %>
                  <%= if @title_edit && @title_edit == card.id do %>
                    <.input
                      type="text"
                      id="title_edit"
                      name="title_edit"
                      value={card.title}
                      phx-value-card={card.id}
                      phx-blur="save"
                      phx-mounted={JS.focus()}
                    />
                  <% else %>
                    <h3
                      tabindex="0"
                      phx-keydown="open_title_edit"
                      phx-key="Enter"
                      phx-click="open_title_edit"
                      phx-value-card={card.id}
                      class="card-title"
                    >
                      {card.title}
                    </h3>
                  <% end %>
                <% end %>

                <%= if @description_edit && @description_edit == card.id do %>
                  <.input
                    type="textarea"
                    id="description_edit"
                    name="description_edit"
                    value={card.description}
                    phx-value-card={card.id}
                    phx-blur="save"
                    phx-mounted={JS.focus()}
                  />
                <% else %>
                  <p
                    tabindex="0"
                    phx-keydown="open_description_edit"
                    phx-key="Enter"
                    phx-click="open_description_edit"
                    phx-value-card={card.id}
                  >
                    {card.description}
                  </p>
                <% end %>

                <div class="card-actions w-full flex justify-between">
                  <%= if card.score != nil do %>
                    <%= if @score_edit && @score_edit == card.id do %>
                      <div
                        style="position: relative; top: 32px; left: -18px; width: 0%; width: 80px; height: 80px;"
                        class="float-left rounded-full badge badge-secondary"
                      >
                        <.input
                          type="number"
                          id="score_edit"
                          name="score_edit"
                          min="1"
                          max="5"
                          value={card.score}
                          phx-value-card={card.id}
                          phx-blur="save"
                          phx-mounted={JS.focus()}
                        />
                      </div>
                    <% else %>
                      <div
                        style="position: relative; top: 32px; left: -18px; width: 0%;"
                        class="float-left rounded-full badge badge-secondary"
                        tabindex="0"
                        phx-keydown="open_score_edit"
                        phx-key="Enter"
                        phx-click="open_score_edit"
                        phx-value-card={card.id}
                      >
                        {card.score}
                      </div>
                    <% end %>
                  <% else %>
                    <div id="score-placeholder"></div>
                  <% end %>
                  <.button
                    type="button"
                    class="btn btn-soft btn-error font-thin text-4xl"
                    style="font-family: 'Brush Script MT'; cursive; position: relative; top: 20px; left: 20px;"
                    phx-click={JS.push("delete", value: %{id: card.id}) |> hide("##{id}")}
                    data-confirm="Are you sure?"
                  >
                    yeet!
                  </.button>
                </div>
              </div>
            </div>
          </.form>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    # assigns we're always gonna assign
    socket =
      socket
      |> assign(:title_edit, nil)
      |> assign(:description_edit, nil)
      |> assign(:score_edit, nil)
      |> assign(:form, to_form(Deck.change_card(%Deck.Card{})))
      |> assign(:new_title, nil)
      |> assign(:new_text, nil)
      |> assign(:new_score, "1")
      |> stream(:cards, [])

    case socket.assigns.live_action do
      :index ->
        {:ok,
         socket
         |> assign(:page_title, "Select Deck")}

      :monikers ->
        {:ok,
         socket
         |> assign(:page_title, "Edit Monikers Cards")
         |> stream(:cards, Deck.monikers() |> Enum.sort(&(&1.id < &2.id)))}

      :cahwhite ->
        {:ok,
         socket
         |> assign(:page_title, "Edit Answer Cards")
         |> stream(:cards, Deck.cahwhite(true) |> Enum.sort(&(&1.id < &2.id)))}

      :cahblack ->
        {:ok,
         socket
         |> assign(:page_title, "Edit Question Cards")
         |> stream(:cards, Deck.cahblack(true) |> Enum.sort(&(&1.id < &2.id)))}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    card = Deck.get_card!(id)
    {:ok, _} = Deck.delete_card(card)

    {:noreply, stream_delete(socket, :cards, card)}
  end

  def handle_event("open_title_edit", %{"card" => id}, socket) do
    card = Deck.get_card!(id)

    socket
    |> assign(:form, to_form(Deck.change_card(card)))

    {:noreply,
     socket |> assign(:title_edit, String.to_integer(id)) |> stream_insert(:cards, card)}
  end

  def handle_event("open_description_edit", %{"card" => id}, socket) do
    card = Deck.get_card!(id)

    {:noreply,
     socket |> assign(:description_edit, String.to_integer(id)) |> stream_insert(:cards, card)}
  end

  def handle_event("open_score_edit", %{"card" => id}, socket) do
    card = Deck.get_card!(id)

    {:noreply,
     socket |> assign(:score_edit, String.to_integer(id)) |> stream_insert(:cards, card)}
  end

  def handle_event("handle_new_title_change", params, socket) do
    IO.inspect(params)
    {:noreply, socket}
  end

  def handle_event("handle_new_text_change", params, socket) do
    IO.inspect(params)
    {:noreply, socket}
  end

  def handle_event("handle_new_score_change", params, socket) do
    IO.inspect(params)
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"card" => card_params}, socket) do
    changeset = Deck.change_card(%Deck.Card{}, card_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event(
        "new_card",
        %{"card" => %{"description" => text, "title" => title, "score" => score}},
        socket
      ) do
    {res, rest} =
      Deck.create_card(%{title: title, description: text, score: score, type: :monikers})

    if res == :ok do
      {:noreply,
       socket
       |> assign(:form, to_form(Deck.change_card(%Deck.Card{})))
       |> stream_insert(:cards, rest)}
    else
      {:noreply,
       socket |> put_flash(:error, "There was an error adding the new card to the database")}
    end
  end

  def handle_event("new_card", %{"card" => %{"description" => text}}, socket) do
    {res, rest} =
      case socket.assigns.live_action do
        :cahwhite ->
          Deck.create_card(%{description: text, type: :cahwhite})

        :cahblack ->
          Deck.create_card(%{description: text, type: :cahblack})
      end

    if res == :ok do
      {:noreply,
       socket
       |> assign(:form, to_form(Deck.change_card(%Deck.Card{})))
       |> stream_insert(:cards, rest)}
    else
      {:noreply,
       socket |> put_flash(:error, "There was an error adding the new card to the database")}
    end
  end

  def handle_event("save", %{"card" => id, "value" => newval}, socket) do
    card = Deck.get_card!(id)

    # jesus wept there has to be a better way of expressing this, right
    editing =
      if socket.assigns.score_edit != nil do
        :score
      else
        if socket.assigns.title_edit != nil do
          :title
        else
          if socket.assigns.description_edit != nil do
            :description
          else
            :wut
          end
        end
      end

    {res, rest} =
      case editing do
        :title ->
          Deck.update_card(card, %{title: newval})

        :description ->
          Deck.update_card(card, %{description: newval})

        :score ->
          Deck.update_card(card, %{score: newval})
      end

    socket =
      socket
      |> assign(:score_edit, nil)
      |> assign(:title_edit, nil)
      |> assign(:description_edit, nil)

    if res == :ok do
      {:reply, %{updated_card_id: card.id}, socket |> stream_insert(:cards, rest)}
    else
      {:noreply,
       socket |> put_flash(:error, "There was an error saving the card to the database")}
    end
  end

  def handle_event(event, params, socket) do
    IO.puts("unhandled #{event} in cards controller with params:\n#{inspect(params)}")
    {:noreply, socket}
  end
end
