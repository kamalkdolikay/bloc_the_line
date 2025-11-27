defmodule BlocTheLineWeb.BlokusBoard do
  use Phoenix.Component
  attr :board, :any, required: true
  attr :opponents, :map, default: %{}

  def blokus_board(assigns) do
    assigns =
      assigns
      |> assign_new(:opponents, fn -> %{} end)
      |> assign(:grid, board_to_grid(assigns.board))

    ~H"""
    <div
      id="blokus-board"
      phx-hook="DebugBoard"
      class="inline-block border border-gray-400 relative"
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
                "blokus-tile w-8 h-8 cursor-pointer relative",
                cell == 1 && "p1-tile",
                cell == 2 && "p2-tile",
                cell == 3 && "p3-tile",
                cell == 4 && "p4-tile",
                cell == 0 && "tile-empty"
              ]}
            >
              <%= for {_pid, %{row: base_row, col: base_col, cells: cells, anchor: {ax, ay}, color: clr}} <- @opponents do %>
                <%= for {x, y} <- cells do %>
                  <% cell_row = base_row + (y - ay) %>
                  <% cell_col = base_col + (x - ax) %>

                  <%= if cell_row == row_index and cell_col == col_index do %>
                    <div
                      class="absolute inset-0 pointer-events-none opacity-60"
                      style={"background-color: #{ghost_color(clr)}"}
                    ></div>
                  <% end %>
                <% end %>
              <% end %>

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

  # Ghost tile colors
  defp ghost_color(color) do
    case color do
      1 -> "#22c55e88"  # green
      2 -> "#3b82f688"  # blue
      3 -> "#f9731688"  # orange
      4 -> "#e11d4888"  # pink/red
      _ -> "#ff00ff88"  # fallback magenta
    end
  end
end
