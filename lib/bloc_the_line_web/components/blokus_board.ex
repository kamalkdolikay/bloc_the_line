defmodule BlocTheLineWeb.BlokusBoard do
  use Phoenix.Component

  attr :board, :list, required: true

  def blokus_board(assigns) do
    ~H"""
    <div
      id="blokus-board"
      phx-hook="MovingBlock"
      data-rows={Enum.count(@board)}
      data-cols={@board |> List.first() |> Enum.count()}
      class="inline-block border border-gray-400 relative"
    >
      <!-- overlay block that will be moved client-side. block-size is in tiles (w x h). -->
      <div class="moving-block" data-block-w="2" data-block-h="2" data-row="0" data-col="0" aria-hidden="true"></div>

      <%= for {row, row_index} <- Enum.with_index(@board) do %>
        <div class="flex blokus-row">
          <%= for {cell, col_index} <- Enum.with_index(row) do %>
            <div
              phx-click="cell_click"
              phx-value-row={row_index}
              phx-value-col={col_index}
              data-row={row_index}
              data-col={col_index}
              class={[
                "blokus-tile w-8 h-8 border border-gray-300 cursor-pointer",
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
