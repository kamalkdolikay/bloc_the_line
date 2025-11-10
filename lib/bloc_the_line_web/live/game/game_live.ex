defmodule BlocTheLineWeb.GameLive do
  use BlocTheLineWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Create a 20x20 empty board for demo
    board = for _ <- 1..20, do: for(_ <- 1..20, do: 0)

    pieces =
      Pieces.all()
      |> Enum.sort_by(fn {_key, piece} -> piece.name end)
      |> Enum.map(fn {_key, piece} ->
        %{
          name: piece.name,
          cells:
            piece.cells
            |> MapSet.to_list()
            # convert the tuples to lists
            |> Enum.map(fn {x, y} -> [x, y] end)
        }
      end)

    {:ok, assign(socket, board: board, counter: 0, pieces: pieces)}
  end

  def handle_event("rotate_piece", %{"cells" => cells, "direction" => direction}, socket) do
    cell_set = cells |> Enum.map(&List.to_tuple/1) |> MapSet.new()

    piece = %Piece{cells: cell_set, corners: MapSet.new(), name: "temp"}

    rotated =
      case direction do
        "cw" -> Piece.rotate(piece, :cw)
        "ccw" -> Piece.rotate(piece, :ccw)
      end

    # convert tuples to lists for json
    cells_as_lists =
      rotated.cells
      |> MapSet.to_list()
      |> Enum.map(fn {x, y} -> [x, y] end)

    {:reply, %{cells: cells_as_lists}, socket}
  end

  def handle_event("flip_piece", %{"cells" => cells, "axis" => axis}, socket) do
    cell_set = cells |> Enum.map(&List.to_tuple/1) |> MapSet.new()
    piece = %Piece{cells: cell_set, corners: MapSet.new(), name: "temp"}

    flipped =
      case axis do
        "horizontal" -> Piece.flip(piece, :horizontal)
        "vertical" -> Piece.flip(piece, :vertical)
      end

    # convert tuples to lists for json
    cells_as_lists =
      flipped.cells
      |> MapSet.to_list()
      |> Enum.map(fn {x, y} -> [x, y] end)

    {:reply, %{cells: cells_as_lists}, socket}
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
