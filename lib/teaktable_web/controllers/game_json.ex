defmodule TeaktableWeb.GameJSON do

  def response(%{res: response, details: details}) do
    %{data: %{response: response, details: details}}
  end
end
