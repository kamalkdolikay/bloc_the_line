defmodule BlocTheLineWeb.BlokusBoard do
  use Phoenix.Component
  attr :board, :any, required: true

  def blokus_board(assigns) do
    # Convert Board struct to 2D list if needed
    assigns = assign(assigns, :grid, board_to_grid(assigns.board))

    ~H"""
    <div
      id="blokus-board"
      class="inline-block border border-gray-400 relative bg-neutral-700"
    >
      <%= for {row, row_index} <- Enum.with_index(@grid) do %>
        <div class="flex blokus-row">
          <%= for {cell, col_index} <- Enum.with_index(row) do %>
            <div
              phx-value-row={row_index}
              phx-value-col={col_index}
              data-row={row_index}
              data-col={col_index}
              class={[
                "blokus-tile bg-neutral-700 w-8 h-8 border border-neutral-500 cursor-pointer",
                cell == 1 && "bg-blue-500",
                cell == 2 && "bg-red-500",
                cell == 3 && "bg-green-500",
                cell == 4 && "bg-yellow-500",
                cell == 0 && "bg-neutral-700"
              ]}
            >
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Convert Board struct to 2D list for rendering
  defp board_to_grid(%Board{width: width, height: height, board_map: board_map}) do
    for row <- 0..(height - 1) do
      for col <- 0..(width - 1) do
        case Map.get(board_map, {col, row}) do
          :p1 -> 1
          :p2 -> 2
          :p3 -> 3
          :p4 -> 4
          nil -> 0
        end
      end
    end
  end

  # If it's already a 2D list (for backwards compatibility), just return it
  defp board_to_grid(board) when is_list(board), do: board
end
