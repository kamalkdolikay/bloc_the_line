defmodule BlocTheLineWeb.GameLive do
  use BlocTheLineWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Create a 20x20 empty board for demo
    board = for _ <- 1..20, do: for(_ <- 1..20, do: 0)

    # convert pieces to lists for JS
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
            |> Enum.map(fn {x, y} -> [x, y] end),
          corners:
            piece.corners
            |> MapSet.to_list()
            |> Enum.map(fn {x, y} -> [x, y] end),
          anchor: Tuple.to_list(piece.anchor)
        }
      end)

    {:ok, assign(socket, board: board, counter: 0, pieces: pieces)}
  end

  def handle_event(
        "rotate_piece",
        %{"cells" => cells, "corners" => corners, "anchor" => anchor, "direction" => direction},
        socket
      ) do
    # convert back to MapSet for elixir
    cell_set = cells |> Enum.map(&List.to_tuple/1) |> MapSet.new()
    corner_set = corners |> Enum.map(&List.to_tuple/1) |> MapSet.new()
    anchor_tuple = List.to_tuple(anchor)

    # turn back into a piece
    piece = %Piece{
      cells: cell_set,
      corners: corner_set,
      name: "temp",
      anchor: anchor_tuple
    }

    # perform operation
    rotated =
      case direction do
        "cw" -> Piece.rotate(piece, :cw)
        "ccw" -> Piece.rotate(piece, :ccw)
      end

    {:reply,
     %{
       cells: MapSet.to_list(rotated.cells) |> Enum.map(fn {x, y} -> [x, y] end),
       corners: MapSet.to_list(rotated.corners) |> Enum.map(fn {x, y} -> [x, y] end),
       anchor: Tuple.to_list(rotated.anchor)
     }, socket}
  end

  def handle_event(
        "flip_piece",
        %{"cells" => cells, "corners" => corners, "anchor" => anchor, "axis" => axis},
        socket
      ) do
    # convert back to MapSet for elixir
    cell_set = cells |> Enum.map(&List.to_tuple/1) |> MapSet.new()
    corner_set = corners |> Enum.map(&List.to_tuple/1) |> MapSet.new()
    anchor_tuple = List.to_tuple(anchor)

    # turn back into a piece
    piece = %Piece{
      cells: cell_set,
      corners: corner_set,
      name: "temp",
      anchor: anchor_tuple
    }

    # perform operation
    flipped =
      case axis do
        "horizontal" -> Piece.flip(piece, :horizontal)
        "vertical" -> Piece.flip(piece, :vertical)
      end

    {:reply,
     %{
       cells: MapSet.to_list(flipped.cells) |> Enum.map(fn {x, y} -> [x, y] end),
       corners: MapSet.to_list(flipped.corners) |> Enum.map(fn {x, y} -> [x, y] end),
       anchor: Tuple.to_list(flipped.anchor)
     }, socket}
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
