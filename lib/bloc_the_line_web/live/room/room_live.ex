defmodule BlocTheLineWeb.RoomLive do
  use BlocTheLineWeb, :live_view
  alias BlocTheLine.Rooms
  require Logger

  # Player name validation: alphanumeric, spaces, hyphens, underscores only, 1-30 chars
  defp validate_player_name(name) when is_binary(name) do
    trimmed = String.trim(name)

    cond do
      trimmed == "" ->
        {:error, "Name cannot be empty"}

      String.length(trimmed) > 30 ->
        {:error, "Name must be 30 characters or less"}

      not Regex.match?(~r/^[a-zA-Z0-9\s\-_]+$/, trimmed) ->
        {:error,
         "Name can only contain letters, numbers, spaces, hyphens (-), and underscores (_)"}

      true ->
        {:ok, trimmed}
    end
  end

  defp validate_player_name(_), do: {:error, "Invalid name format"}

  # Get a safe initial for avatar display (handles edge cases)
  def get_avatar_initial(name) when is_binary(name) do
    trimmed = String.trim(name)

    case String.first(trimmed) do
      nil ->
        "?"

      char when char in ["-", "_"] ->
        # If first char is a special allowed char, try to find a letter/number
        case Regex.run(~r/[a-zA-Z0-9]/, trimmed) do
          [first_valid | _] -> String.upcase(first_valid)
          nil -> "?"
        end

      char ->
        # Extract first alphanumeric character and uppercase it
        if Regex.match?(~r/^[a-zA-Z0-9]$/, char) do
          String.upcase(char)
        else
          "?"
        end
    end
  end

  def get_avatar_initial(_), do: "?"

  def mount(params, _session, socket) do
    room_code = params["room_code"]
    # Decode URL-encoded player name (spaces are encoded as + in query strings)
    # Replace + with spaces first, then decode any %-encoded characters
    player_name =
      (params["name"] || "")
      |> String.replace("+", " ")
      |> URI.decode()

    # Guard against missing room codes (e.g. /room without code).
    if room_code in [nil, ""] do
      {:ok, socket |> put_flash(:error, "Invalid room") |> push_navigate(to: ~p"/")}
    else
      if connected?(socket) do
        # If no name provided, generate a guest name. Otherwise validate the name.
        chosen_name_result =
          if String.trim(player_name) == "" do
            {:ok, generate_guest_name()}
          else
            validate_player_name(player_name)
          end

        case chosen_name_result do
          {:error, message} ->
            {:ok,
             socket
             |> put_flash(:error, message)
             |> push_navigate(to: ~p"/?room_code=#{room_code}")}

          {:ok, chosen_name} ->
            case Rooms.join_room(room_code, chosen_name) do
              {:ok, player_id} ->
                Phoenix.PubSub.subscribe(BlocTheLine.PubSub, "room:#{room_code}")
                {:ok, room_state} = Rooms.get_room(room_code)

                board = room_state.board

                # Get the player's color (1-4) to display as P1, P2, P3, P4 and cur piece
                player = Map.get(room_state.players, player_id)
                player_color = player.color || 1
                piece_name =
                  if player.current_piece,
                  do: player.current_piece.name,
                  else: nil

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
                 |> assign(:player_name, chosen_name)
                 |> assign(:player_color, player_color)
                 |> assign(:players, room_state.players)
                 |> assign(:public, Map.get(room_state, :public, false))
                 |> assign(:board, board)
                 |> assign(:pieces, pieces)
                 |> assign(:copied, false)
                 |> assign(:editing_name, false)
                 |> assign(:host_id, Map.get(room_state, :host_id))
                 |> assign(:game_started, Map.get(room_state, :game_started, false))
                 |> assign(:my_corner, player.corner)     # unused
                 |> assign(:last_placed_position, nil)
                 |> assign(:timer_seconds, Map.get(room_state, :timer_seconds, 60))
                 |> assign(:assigned_piece, piece_name)
                 |> assign(:game_over, false)
                 |> assign(:game_over_reason, nil)
                 |> assign(:winners, [])
                }

              {:error, :room_not_found} ->
                {:ok, socket |> put_flash(:error, "Room not found") |> push_navigate(to: ~p"/")}

              {:error, :room_full} ->
                {:ok, socket |> put_flash(:error, "Room is full") |> push_navigate(to: ~p"/")}

              {:error, :duplicate_name} ->
                {:ok,
                 socket
                 |> put_flash(
                   :error,
                   "A player with that name already exists in this room. Please choose a different name."
                 )
                 |> push_navigate(to: ~p"/?room_code=#{room_code}")}

              {:error, :game_already_started} ->
                {:ok,
                 socket
                 |> put_flash(
                   :error,
                   "This game has already started. You cannot join a game in progress."
                 )
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
         |> assign(:public, false)
         |> assign(:board, board)
         |> assign(:pieces, [])
         |> assign(:copied, false)
         |> assign(:editing_name, false)
         |> assign(:host_id, nil)
         |> assign(:game_started, false)
         |> assign(:my_corner, {0, 0})
         |> assign(:last_placed_position, nil)
         |> assign(:game_over, false)
         |> assign(:game_over_reason, nil)
         |> assign(:assigned_piece, nil)
         |> assign(:timer_seconds, 60)
         |> assign(:winners, [])
        }
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
        # Send error event to frontend to trigger shake animation
        {:noreply,
         socket
         |> push_event("piece_placement_error", %{reason: inspect(reason)})}
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
  def handle_event(
        "update_position",
        %{"piece" => piece, "row" => row, "col" => col, "cells" => cells, "anchor" => anchor},
        socket
      ) do
    coord = {col, row}

    # Update position in the Rooms module
    Rooms.update_position(
      socket.assigns.room_code,
      socket.assigns.player_id,
      piece,
      coord,
      cells,
      anchor
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

  def handle_event("piece_changed", %{"piece" => piece}, socket) do
    # TODO: this and handle_event("piece_change") do the same thing?
    # players =
    #   Map.update!(socket.assigns.players, player_id, fn p ->
    #     piece = String.to_atom(piece_name) |> Pieces.get()
    #     Player.set_current_piece(p, piece)
    #   end)

    Phoenix.PubSub.broadcast(
      BlocTheLine.PubSub,
      "room:#{socket.assigns.room_code}",
      {:piece_changed, socket.assigns.player_id, piece}
    )

    # {:noreply, assign(socket, players: players)}
    {:noreply, socket}
  end

  def handle_event("start_edit_name", _params, socket) do
    {:noreply, assign(socket, :editing_name, true)}
  end

  def handle_event("cancel_edit_name", _params, socket) do
    {:noreply, assign(socket, :editing_name, false)}
  end

  def handle_event("update_timer_seconds", %{"seconds" => seconds}, socket) do
    # Convert seconds from string to integer
    seconds = String.to_integer(seconds)
    Rooms.update_timer_seconds(socket.assigns.room_code, seconds)
    {:noreply, assign(socket, timer_seconds: seconds)}
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

  def handle_info({:timer_update, seconds}, socket) do
    {:noreply, assign(socket, :timer_seconds, seconds)}
  end

  def handle_info({:game_over, :timeout}, socket) do
    players = socket.assigns.players
    highest_score =
      players
      |> Enum.map(fn {_, p} -> p.points end)
      |> Enum.max()

    winners =
      players
      |> Enum.filter(fn {_, p} -> p.points == highest_score end)
      |> Enum.map(fn {_, p} -> p end)

    {:noreply,
     socket
     |> assign(:winners, winners)
     |> assign(:game_over, true)
     |> assign(:game_over_reason, :timeout)
     |> put_flash(:info, "Time's up! Game over.")
     |> assign(:timer_seconds, 0)}
  end

  def handle_info({:player_ready_changed, player_id, ready}, socket) do
    players =
      Map.update!(socket.assigns.players, player_id, fn player -> %{player | ready: ready} end)

    {:noreply, assign(socket, :players, players)}
  end

  # Game-over broadcast from RoomServer
  def handle_info({:game_over, reason}, socket) do
    players = socket.assigns.players
    highest_score =
      players
      |> Enum.map(fn {_, p} -> p.points end)
      |> Enum.max()

    winners =
      players
      |> Enum.filter(fn {_, p} -> p.points == highest_score end)
      |> Enum.map(fn {_, p} -> p end)

    socket =
      socket
      |> assign(:winners, winners)
      |> assign(:game_over, true)
      |> assign(:game_over_reason, reason)
      # IMPORTANT: do NOT set :game_started to false here
      |> push_event("game_over", %{reason: to_string(reason)})

    {:noreply, socket}
  end

  # TODO: prob better to change this to get the corner data from the player struct instead
  def handle_info({:game_started, player_corners}, socket) do
    my_corner = Map.get(player_corners, socket.assigns.player_id, {0, 0})
    {col, row} = my_corner

    # Get the assigned piece NAME for this player after game starts
    assigned_piece =
      if socket.assigns.player_id do
        Rooms.get_assigned_piece(socket.assigns.room_code, socket.assigns.player_id)
      else
        nil
      end

    {:noreply,
     socket
     |> assign(:game_started, true)
     |> assign(:player_corners, player_corners)
     |> assign(:my_corner, my_corner)
     # Initialize to corner
     |> assign(:last_placed_position, my_corner)
     |> assign(:assigned_piece, assigned_piece)
     # NEW: clear any previous game-over state
     |> assign(:game_over, false)
     |> assign(:game_over_reason, nil)
     |> push_event("game_started", %{col: col, row: row})}
  end

  def handle_info({:piece_assigned, player_id, piece_name}, socket) do
    # Only update if this is for the current player
    if player_id == socket.assigns.player_id do
      {:noreply,
       socket
       |> assign(:assigned_piece, piece_name)
       |> push_event("piece_assigned", %{piece_name: piece_name})}
    else
      {:noreply, socket}
    end
  end

  # Player joined/left handlers
  def handle_info({:player_joined, player}, socket) do
    players = Map.put(socket.assigns.players, player.id, player)
    socket = assign(socket, :players, players)
    socket =
      if socket.assigns.player_id == player.id do
        # Probably the default_color is not needed but Im leaving it for legacy safety
        default_color = socket.assigns.player_color || 1
        assign(socket, :player_color, player.color || default_color)
      else
        socket
      end

    {:noreply, socket}
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

  def handle_info({:piece_changed, player_id, piece_name}, socket) do
    players =
      Map.update!(socket.assigns.players, player_id, fn p ->
        piece = String.to_atom(piece_name) |> Pieces.get()
        Player.set_current_piece(p, piece)
      end)

    {:noreply, assign(socket, players: players)}
  end

  def handle_info({:piece_placed, player_id, row, col, cells, player_points, new_board}, socket) do
    IO.inspect(player_id, label: "PIECE PLACED BY")
    IO.inspect({row, col}, label: "AT POSITION")
    IO.inspect(cells, label: "WITH CELLS")
    IO.inspect(player_points, label: "PLAYER_SCORE")
    IO.inspect(new_board, label: "NEW BOARD")
    IO.inspect(socket.assigns.board, label: "OLD BOARD")

    players =
      Map.update!(socket.assigns.players, player_id, fn p ->
        %{p | points: player_points}
      end)


    # Track last placed position for this player
    updated_socket =
      if player_id == socket.assigns.player_id do
        socket
        |> assign(:last_placed_position, {col, row})
        |> push_event("piece_placed", %{col: col, row: row})
      else
        socket
      end

      {:noreply,
      updated_socket
      |> assign(:board, new_board)
      |> assign(:players, players)}
  end

  # serve player position updates to frontend
  def handle_info({:position_updated, player_id, piece_name, coord, cells, anchor}, socket) do
    {col, row} = coord
    {anchor_col, anchor_row} = anchor
    player = Map.get(socket.assigns.players, player_id)

    {:noreply,
     socket
     |> push_event("position_updated", %{
       player_id: player_id,
       piece: piece_name,
       row: row,
       col: col,
       cells: cells,
       anchor: [anchor_col, anchor_row], # Had to cast it because Jason doesn't serialize tuples
       # send the colour of the updated piece so frontend knows how to render it
       color: player.color
     })}
  end



  # Handle remote player name change broadcasts
  def handle_info({:player_name_changed, player_id, new_name}, socket) do
    players =
      Map.update(socket.assigns.players, player_id, nil,
        fn p -> Player.rename(p, new_name) end)

    socket = assign(socket, :players, players)

    socket =
      if socket.assigns.player_id == player_id do
        assign(socket, :player_name, new_name)
      else
        socket
      end

    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    if socket.assigns[:player_id],
      do: Rooms.leave_room(socket.assigns.room_code, socket.assigns.player_id)
    :ok
  end

  # Check if all players are ready
  defp all_ready?(players) do
    Enum.all?(players, fn {_id, player} -> player.ready end)
  end

  defp generate_guest_name do
    suffix = :crypto.strong_rand_bytes(2) |> Base.encode16() |> String.slice(0, 4)
    "Guest-" <> suffix
  end
end
