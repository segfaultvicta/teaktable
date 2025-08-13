defmodule TeaktableWeb.CardHTML do
  use TeaktableWeb, :html

  embed_templates "card_html/*"

  @doc """
  Renders a card form.

  The form is defined in the template at
  card_html/card_form.html.heex
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def card_form(assigns)
end
