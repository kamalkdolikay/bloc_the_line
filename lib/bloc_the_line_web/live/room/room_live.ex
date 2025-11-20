defmodule BlocTheLineWeb.RoomLive do
  use BlocTheLineWeb, :live_view
  alias BlocTheLine.Rooms
  require Logger

  def mount(params, _session, socket) do
    room_code = params["room_code"]
    player_name = params["name"] || ""

    # Guard against missing room codes (e.g. /room without code).
    if room_code in [nil, ""] do
      {:ok, socket |> put_flash(:error, "Invalid room") |> push_navigate(to: ~p"/")}
    else
      if connected?(socket) do
        # Require a name to join; do not auto-create guest names on the server.
        if String.trim(player_name || "") == "" do
          {:ok,
           socket
           |> put_flash(:error, "Please enter your name to join a room")
           |> push_navigate(to: ~p"/")}
        else
          case Rooms.join_room(room_code, player_name) do
            {:ok, player_id} ->
              Phoenix.PubSub.subscribe(BlocTheLine.PubSub, "room:#{room_code}")
              {:ok, room_state} = Rooms.get_room(room_code)

              # Get the board from room state (not empty!)
              board = room_state.board

              # Get all pieces for the MovingBlock hook
              pieces =
                Pieces.all()
                |> Enum.sort_by(fn {_key, piece} -> piece.name end)
                |> Enum.map(fn {_key, piece} ->
                  %{
                    name: piece.name,
                    cells:
                      piece.cells
                      |> MapSet.to_list()
                      |> Enum.map(fn {x, y} -> [x, y] end),
                    corners:
                      piece.corners
                      |> MapSet.to_list()
                      |> Enum.map(fn {x, y} -> [x, y] end),
                    anchor: Tuple.to_list(piece.anchor)
                  }
                end)

              {:ok,
               socket
               |> assign(:room_code, room_code)
               |> assign(:player_id, player_id)
               |> assign(:player_name, player_name)
               |> assign(:players, room_state.players)
               |> assign(:public, Map.get(room_state, :public, false))
               |> assign(:board, board)
               |> assign(:pieces, pieces)
               |> assign(:copied, false)}

            {:error, :room_not_found} ->
              {:ok,
               socket
               |> put_flash(:error, "Room not found")
               |> push_navigate(to: ~p"/")}

            {:error, :room_full} ->
              {:ok,
               socket
               |> put_flash(:error, "Room is full")
               |> push_navigate(to: ~p"/")}

            {:error, reason} ->
              Logger.warning("Failed to join room #{inspect(room_code)}: #{inspect(reason)}")

              {:ok,
               socket
               |> put_flash(:error, "Unable to join room")
               |> push_navigate(to: ~p"/")}
          end
        end
      else
        # Not connected yet - get board if room exists
        board =

        case Rooms.room_exists?(room_code) do
              true ->
                case Rooms.get_room(room_code) do
                  {:ok, room_state} -> room_state.board
                  _ -> for _ <- 1..20, do: for(_ <- 1..20, do: 0)
                end


          false ->
                for _ <- 1..20, do: for(_ <- 1..20, do: 0)
            end

        {:ok,
         socket
         |> assign(:room_code, room_code)
         |> assign(:player_id, nil)
         |> assign(:player_name, player_name)
         |> assign(:players, %{})
         |> assign(:board, board)
         |> assign(:pieces, [])
         |> assign(:public, false)
         |> assign(:copied, false)}
      end
    end
  end

  # Handle placing a piece (triggered by SPACE key)
  def handle_event("place_piece", %{"row" => row_str, "col" => col_str, "cells" => cells}, socket) do
    row = String.to_integer(row_str)
    col = String.to_integer(col_str)

    IO.inspect({row, col, cells}, label: "Placing piece")

    case Rooms.place_piece(socket.assigns.room_code, socket.assigns.player_id, row, col, cells) do
      {:ok, _new_board} ->
        {:noreply, socket}

      {:error, reason} ->
        IO.inspect(reason, label: "Failed to place piece")
        {:noreply, socket}
    end
  end

  # Handle rotate/flip events from MovingBlock hook
  def handle_event("rotate_piece", params, socket) do
    cells = params["cells"] |> Enum.map(&List.to_tuple/1) |> MapSet.new()
    corners = params["corners"] |> Enum.map(&List.to_tuple/1) |> MapSet.new()
    anchor = params["anchor"] |> List.to_tuple()

    piece = %Piece{cells: cells, corners: corners, name: "temp", anchor: anchor}

    rotated =
      case params["direction"] do
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

  def handle_event("flip_piece", params, socket) do
    cells = params["cells"] |> Enum.map(&List.to_tuple/1) |> MapSet.new()
    corners = params["corners"] |> Enum.map(&List.to_tuple/1) |> MapSet.new()
    anchor = params["anchor"] |> List.to_tuple()

    piece = %Piece{cells: cells, corners: corners, name: "temp", anchor: anchor}

    flipped =
      case params["axis"] do
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

  def handle_event("copy_link", _params, socket) do
    {:noreply, assign(socket, :copied, true)}
  end

  def handle_event("toggle_public", _params, socket) do
    new_public = not Map.get(socket.assigns, :public, false)

    case Rooms.set_public(socket.assigns.room_code, new_public) do
      :ok ->
        {:noreply, assign(socket, :public, new_public)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("reset_copied", _params, socket) do
    {:noreply, assign(socket, :copied, false)}
  end

  # Player joined/left handlers
  def handle_info({:player_joined, player}, socket) do
    {:noreply, assign(socket, :players, Map.put(socket.assigns.players, player.id, player))}
  end

  def handle_info({:public_changed, public}, socket) do
    {:noreply, assign(socket, :public, public)}
  end

  def handle_info({:player_left, player}, socket) do
    {:noreply, assign(socket, :players, Map.delete(socket.assigns.players, player.id))}
  end

  def handle_info({:piece_placed, player_id, row, col, cells, new_board}, socket) do
    IO.inspect(player_id, label: "PIECE PLACED BY")
    IO.inspect({row, col}, label: "AT POSITION")
    IO.inspect(cells, label: "WITH CELLS")
    IO.inspect(new_board, label: "NEW BOARD")
    IO.inspect(socket.assigns.board, label: "OLD BOARD")
    {:noreply, assign(socket, :board, new_board)}
  end

  def terminate(_reason, socket) do
    if socket.assigns[:player_id],
      do: Rooms.leave_room(socket.assigns.room_code, socket.assigns.player_id)

    :ok
  end
end
