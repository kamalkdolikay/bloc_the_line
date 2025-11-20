defmodule BlocTheLineWeb.PlayerCard do
  use Phoenix.Component

  def player_card(assigns) do
    ~H"""
    <div class={@class}>
      <div>
        {@name}
      </div>
    </div>
    """
  end
end
