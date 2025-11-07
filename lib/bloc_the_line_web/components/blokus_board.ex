defmodule BlocTheLineWeb.BlokusBoard do
  use Phoenix.Component

  attr :board, :list, required: true

  def blokus_board(assigns) do
    ~H"""
    <div class="inline-block border border-gray-400">
      <%= for {row, row_index} <- Enum.with_index(@board) do %>
        <div class="flex">
          <%= for {cell, col_index} <- Enum.with_index(row) do %>
            <div
              phx-click="cell_click"
              phx-value-row={row_index}
              phx-value-col={col_index}
              class={[
                "w-8 h-8 border border-gray-300 cursor-pointer",
                cell == 1 && "bg-blue-500",
                cell == 0 && "bg-white"
              ]}
            >
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
