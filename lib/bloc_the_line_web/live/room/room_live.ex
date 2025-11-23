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
        # If no name provided, generate a guest name and join the room.
        chosen_name = if String.trim(player_name) == "", do: generate_guest_name(), else: player_name

        case Rooms.join_room(room_code, chosen_name) do
          {:ok, player_id} ->
            Phoenix.PubSub.subscribe(BlocTheLine.PubSub, "room:#{room_code}")
            {:ok, room_state} = Rooms.get_room(room_code)

            board = room_state.board

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
             |> assign(:player_name, chosen_name)
             |> assign(:players, room_state.players)
             |> assign(:public, Map.get(room_state, :public, false))
             |> assign(:board, board)
             |> assign(:pieces, pieces)
               |> assign(:copied, false)
               |> assign(:editing_name, false)}

          {:error, :room_not_found} ->
            {:ok, socket |> put_flash(:error, "Room not found") |> push_navigate(to: ~p"/")}

          {:error, :room_full} ->
            {:ok, socket |> put_flash(:error, "Room is full") |> push_navigate(to: ~p"/")}

          {:error, reason} ->
            Logger.warning("Failed to join room #{inspect(room_code)}: #{inspect(reason)}")

            {:ok, socket |> put_flash(:error, "Unable to join room") |> push_navigate(to: ~p"/")}
        end
      else
        # Not connected yet - show a lightweight preview if the room exists
        board =
          case Rooms.room_exists?(room_code) do
            true ->
              case Rooms.get_room(room_code) do
                {:ok, room_state} -> room_state.board
                _ -> Board.new(20, 20, 4)
              end

            false ->
              Board.new(20, 20, 4)
          end

        {:ok,
         socket
         |> assign(:room_code, room_code)
         |> assign(:player_id, nil)
         |> assign(:player_name, player_name)
         |> assign(:player_color, 1)
         |> assign(:players, %{})
         |> assign(:board, board)
         |> assign(:pieces, [])
         |> assign(:public, false)
         |> assign(:copied, false)
         |> assign(:editing_name, false)}
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

  # Handling ready
  def handle_event("toggle_ready", %{"ready" => ready}, socket) do
    ready_bool = ready == "true"
    BlocTheLine.Rooms.set_ready(socket.assigns.room_code, socket.assigns.player_id, ready_bool)
    {:noreply, socket}
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

  # handle player position updates from frontend
  def handle_event("update_position", %{"piece" => piece, "row" => row, "col" => col}, socket) do
    coord = {col, row}

    Rooms.update_position(
      socket.assigns.room_code,
      socket.assigns.player_id,
      piece,
      coord
    )

    {:noreply, socket}
  end

  def handle_event("reset_copied", _params, socket) do
    {:noreply, assign(socket, :copied, false)}
  end

  # Handler for starting game as the "host"
  def handle_event("start_game", _params, socket) do
    BlocTheLine.Rooms.start_game(socket.assigns.room_code)
    {:noreply, socket}
  end

  def handle_info({:player_ready_changed, player_id, ready}, socket) do
    players =
      Map.update!(socket.assigns.players, player_id, fn player -> %{player | ready: ready} end)

    {:noreply, assign(socket, :players, players)}
  end

  def handle_info({:game_started, player_corners}, socket) do
    my_corner = Map.get(player_corners, socket.assigns.player_id, {0, 0})
    {col, row} = my_corner

    {:noreply,
     socket
     |> assign(:game_started, true)
     |> assign(:player_corners, player_corners)
     |> assign(:my_corner, my_corner)
     # Initialize to corner
     |> assign(:last_placed_position, my_corner)
     |> push_event("game_started", %{col: col, row: row})}
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

  def handle_info({:host_changed, new_host_id}, socket) do
    {:noreply, assign(socket, :host_id, new_host_id)}
  end

  def handle_info({:piece_placed, player_id, row, col, cells, new_board}, socket) do
    IO.inspect(player_id, label: "PIECE PLACED BY")
    IO.inspect({row, col}, label: "AT POSITION")
    IO.inspect(cells, label: "WITH CELLS")
    IO.inspect(new_board, label: "NEW BOARD")
    IO.inspect(socket.assigns.board, label: "OLD BOARD")

    # Track last placed position for this player
    updated_socket =
      if player_id == socket.assigns.player_id do
        socket
        |> assign(:last_placed_position, {col, row})
        |> push_event("piece_placed", %{col: col, row: row})
      else
        socket
      end

    {:noreply, assign(updated_socket, :board, new_board)}
  end

  # serve player position updates to frontend
  def handle_info({:position_updated, player_id, piece, coord}, socket) do
    {col, row} = coord

    {:noreply,
     socket
     |> push_event("position_updated", %{
       player_id: player_id,
       piece: piece,
       row: row,
       col: col,
       # send the colour of the updated piece so frontend knows how to render it
       color: get_in(socket.assigns.players, [player_id, :color])
     })}
  end

  # Check if all players are ready
  defp all_ready?(players) do
    Enum.all?(players, fn {_id, player} -> player.ready end)
  end

  def terminate(_reason, socket) do
    if socket.assigns[:player_id],
      do: Rooms.leave_room(socket.assigns.room_code, socket.assigns.player_id)

    :ok
  end

  # Handle remote player name change broadcasts
  def handle_info({:player_name_changed, player_id, new_name}, socket) do
    players = Map.update(socket.assigns.players, player_id, nil, fn p -> Map.put(p, :name, new_name) end)
    socket = assign(socket, :players, players)

    socket =
      if socket.assigns.player_id == player_id do
        assign(socket, :player_name, new_name)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("start_edit_name", _params, socket) do
    {:noreply, assign(socket, :editing_name, true)}
  end

  def handle_event("cancel_edit_name", _params, socket) do
    {:noreply, assign(socket, :editing_name, false)}
  end

  def handle_event("save_name", %{"new_name" => new_name}, socket) do
    new_name = String.trim(new_name || "")

    if new_name == "" do
      {:noreply, socket}
    else
      case Rooms.update_player_name(socket.assigns.room_code, socket.assigns.player_id, new_name) do
        :ok ->
          {:noreply, assign(socket, :editing_name, false) |> assign(:player_name, new_name)}

        {:error, _} ->
          {:noreply, socket}
      end
    end
  end

  defp generate_guest_name do
    suffix = :crypto.strong_rand_bytes(2) |> Base.encode16() |> String.slice(0, 4)
    "Guest-" <> suffix
  end
end
