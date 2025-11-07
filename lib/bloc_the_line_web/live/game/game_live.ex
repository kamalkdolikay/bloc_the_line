defmodule BlocTheLineWeb.GameLive do
  use BlocTheLineWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Create a 5x5 empty board for demo
    board = for _ <- 1..5, do: for(_ <- 1..5, do: 0)
    {:ok, assign(socket, board: board, counter: 0)}
  end

  @impl true
  def handle_event("inc", _value, socket) do
    {:noreply, update(socket, :counter, &(&1 + 1))}
  end

  def handle_event("cell_click", %{"row" => r, "col" => c}, socket) do
    row = String.to_integer(r)
    col = String.to_integer(c)

    # Log the clicked cell to the server console
    IO.inspect({row, col}, label: "Cell clicked")

    # No change to the board
    {:noreply, socket}
  end
end
