defmodule BlocTheLineWeb.BlokusBoard do
  use Phoenix.Component
  attr :board, :list, required: true

  def blokus_board(assigns) do
    ~H"""
    <div
      id="blokus-board"
      class="inline-block border border-gray-400 relative"
    >
      <%= for {row, row_index} <- Enum.with_index(@board) do %>
        <div class="flex blokus-row">
          <%= for {cell, col_index} <- Enum.with_index(row) do %>
            <div
              phx-value-row={row_index}
              phx-value-col={col_index}
              data-row={row_index}
              data-col={col_index}
              class={
                [
                  "blokus-tile w-8 h-8 border border-gray-300 cursor-pointer",
                  # cell == 1 && "bg-blue-600",
                  # cell == 2 && "bg-red-600",
                  # cell == 3 && "bg-green-600",
                  # cell == 4 && "bg-yellow-600",
                  # cell == 0 && "bg-white"

                  cell == 1 && "bg-blue-500 border-2 border-blue-700",
                  cell == 2 && "bg-red-500 border-2 border-red-700",
                  cell == 3 && "bg-purple-500 border-2 border-purple-700",
                  cell == 4 && "bg-yellow-500 border-2 border-yellow-700",
                  cell == 0 && "bg-white"
                ]
              }
            >
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
