defmodule BlocTheLine.Rooms.RoomServer do
  use GenServer
  require Logger
  alias Pieces

  def start_link(room_code) do
    GenServer.start_link(__MODULE__, room_code, name: via_tuple(room_code))
  end

  def join(room_code, player_name) do
    GenServer.call(via_tuple(room_code), {:join, player_name})
  end

  def leave(room_code, player_id) do
    GenServer.call(via_tuple(room_code), {:leave, player_id})
  end

  def get_state(room_code) do
    GenServer.call(via_tuple(room_code), :get_state)
  end

  def list_players(room_code) do
    GenServer.call(via_tuple(room_code), :list_players)
  end

  def place_piece(room_code, player_id, row, col, cells) do
    GenServer.call(via_tuple(room_code), {:place_piece, player_id, row, col, cells})
  end

  def update_player_name(room_code, player_id, new_name) do
    GenServer.call(via_tuple(room_code), {:update_name, player_id, new_name})
  end

  def get_board(room_code) do
    GenServer.call(via_tuple(room_code), :get_board)
  end

  def set_public(room_code, public) when is_boolean(public) do
    GenServer.call(via_tuple(room_code), {:set_public, public})
  end

  # For the ready function
  def set_ready(room_code, player_id, ready) do
    GenServer.call(via_tuple(room_code), {:set_ready, player_id, ready})
  end

  def start_game(room_code) do
    GenServer.call(via_tuple(room_code), :start_game)
  end

  def update_position(room_code, player_id, piece, coord, cells, anchor) when is_tuple(coord) do
    GenServer.call(
      via_tuple(room_code),
      {:update_position, player_id, piece, coord, cells, anchor}
    )
  end

  def get_assigned_piece(room_code, player_id) do
    GenServer.call(via_tuple(room_code), {:get_assigned_piece, player_id})
  end

  # TODO: Add the corners
  @impl true
  def init(room_code) do
    state = %{
      room_code: room_code,
      # %{player_id => Player.t()}
      players: %{},
      board: Board.new(20, 20, 4),
      created_at: DateTime.utc_now(),
      game_started: false,
      next_player_color: 1,
      public: false,
      # ref to player_process => player_id
      monitors: %{},
      # player_id => ref to player_process (backwards map for lookup)
      player_refs: %{}
    }

    Logger.info("Room #{room_code} created")
    {:ok, state}
  end

  @impl true
  def handle_call({:join, player_name}, {from_pid, _ref} = _from, state) do
    cond do
      state.game_started ->
        {:reply, {:error, :game_already_started}, state}

      map_size(state.players) >= 4 ->
        {:reply, {:error, :room_full}, state}

      true ->
        # Check for duplicate names
        name_exists? =
          state.players
          |> Map.values()
          |> Enum.any?(fn player ->
            String.downcase(player.name) == String.downcase(player_name)
          end)

        if name_exists? do
          {:reply, {:error, :duplicate_name}, state}
        else
          new_player = Player.new(
            player_name,
            state.next_player_color,
            {0, 0},                 # TODO: add that players' corner
            DateTime.utc_now()
          )

          ref = Process.monitor(from_pid)

          Logger.debug(
            "Monitoring pid=#{inspect(from_pid)} ref=#{inspect(ref)} for player=#{new_player.id}"
          )

          # record the monitor ref -> new_player.id and new_player.id -> ref so we can cleanup on DOWN
          monitors = Map.put(state.monitors, ref, new_player.id)
          player_refs = Map.put(state.player_refs, new_player.id, ref)
          new_players = Map.put(state.players, new_player.id, new_player)

          new_state =
            state
            |> Map.put(:players, new_players)
            # cycle the color
            |> Map.put(:next_player_color, rem(new_player.color, 4) + 1)
            |> Map.put(:monitors, monitors)
            |> Map.put(:player_refs, player_refs)

          # Assign host_id if this is the first player
          new_state =
            if map_size(state.players) == 0 do
              Map.put(new_state, :host_id, new_player.id)
            else
              new_state
            end

          Phoenix.PubSub.broadcast(
            BlocTheLine.PubSub,
            "room:#{state.room_code}",
            {:player_joined, new_player}
          )

          Logger.info(
            "Player #{player_name} (#{new_player.id}) joined room #{state.room_code} as color #{new_player.color}"
          )

          {:reply, {:ok, new_player.id}, new_state}
        end
    end
  end

  # Set the player's ready variable
  # ! IMPORTANT: Function only works if the user is certified to be in the room.
  # I didn't want to dive too much into refactoring, so just a quick note
  @impl true
  def handle_call({:set_ready, player_id, ready}, _from, state) do
    player = Map.get(state.players, player_id)
    new_player = %Player{player | ready: ready}
    new_state = %{state |
      players: Map.replace(state.players, player_id, new_player)
    }

    Phoenix.PubSub.broadcast(
      BlocTheLine.PubSub,
      "room:#{state.room_code}",
      {:player_ready_changed, player_id, ready}
    )

    {:reply, :ok, new_state}
  end

  # Sets the game_started variable to true to start the game
  @impl true
  def handle_call(:start_game, _from, state) do
    # Assign corners to players based on their colors
    player_corners = assign_corners_to_players(state.players)

    # Assign random pieces to all players
    # Map from player_id to random_piece (Piece)
    random_pieces =
      state.players
      |> Map.keys()
      |> Enum.reduce(%{}, fn player_id, acc ->
        random_piece =
          Pieces.random_starting_piece_name()
          |> Pieces.get()
        Map.put(acc, player_id, random_piece)
      end)

    # Updates players with their corners and current piece
    new_players =
      state.players
      |> Map.new(fn player_id, player ->
        corner = Map.get(player_corners, player_id)
        piece = Map.get(random_pieces, player_id)
        new_player =
          player
          |> Player.update_corner(corner)
          |> Player.set_current_piece(piece)
        {player_id, new_player}
      end)

    new_state = %{
      state
      | players: new_players
    }

    # Broadcast piece assignments to all players (by their str names)
    Enum.each(random_pieces, fn {player_id, piece} ->
      Phoenix.PubSub.broadcast(
        BlocTheLine.PubSub,
        "room:#{state.room_code}",
        {:piece_assigned, player_id, piece.name}
      )
    end)

    Phoenix.PubSub.broadcast(
      BlocTheLine.PubSub,
      "room:#{state.room_code}",
      {:game_started, player_corners}
    )

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:leave, player_id}, _from, state) do
    {player, new_players} = Map.pop(state.players, player_id)

    # If the leaving player is the host assign host_id to the next player (if any)
    new_host_id =
      if state.host_id == player_id do
        case Map.keys(new_players) do
          [next_host | _] -> next_host
          [] -> nil
        end
      else
        state.host_id
      end

    new_state = %{state | players: new_players, host_id: new_host_id}

    if player do
      Phoenix.PubSub.broadcast(
        BlocTheLine.PubSub,
        "room:#{state.room_code}",
        {:player_left, player}
      )

      # Broadcast host change if the host changed
      if state.host_id == player_id and new_host_id != nil do
        Phoenix.PubSub.broadcast(
          BlocTheLine.PubSub,
          "room:#{state.room_code}",
          {:host_changed, new_host_id}
        )
      end

      Logger.info("Player #{player.name} left room #{state.room_code}")
    end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:list_players, _from, state) do
    {:reply, Map.values(state.players), state}
  end

  # ! IMPORTANT: Function only works if the user is certified to be in the room.
  # I didn't want to dive too much into refactoring, so just a quick note
  @impl true
  def handle_call({:place_piece, player_id, row, col, cells}, _from, state) do
    player = Map.get(state.players, player_id)
    player_atom = color_to_player(player.color)

    # Convert cells to a Piece struct
    # TODO: Maybe use a function to transform into the pre chosen pieces, OR EVEN BETTER:
    #       Change this to use the piece name instead
    piece = cells_to_piece(cells)

    # Use Board.add_piece with validation, passing the player's assigned corner
    case Board.add_piece(state.board, piece, {col, row}, player_atom, player.corner) do
      {:ok, new_board} ->
        # Assign a new random piece after successful placement
        random_piece = Pieces.random_piece_name() |> Pieces.get()
        new_player =
          player
          |> Player.add_points_by_piece(piece)
          |> Player.set_current_piece(piece)

        new_state = %{state |
          board: new_board,
          players: Map.replace(state.players, player_id, new_player)
        }

        Phoenix.PubSub.broadcast(
          BlocTheLine.PubSub,
          "room:#{state.room_code}",
          {:piece_placed, player_id, row, col, cells, new_player.points, new_board}
        )

        Phoenix.PubSub.broadcast(
          BlocTheLine.PubSub,
          "room:#{state.room_code}",
          {:piece_assigned, player_id, random_piece.name}
        )

        Logger.info(
          "#{player_id} (#{player_atom}) placed piece at (#{row}, #{col}) in room #{state.room_code}"
        )

        {:reply, {:ok, new_board}, new_state}

      {:err, _board} ->
        Logger.warning(
          "#{player_id} (#{player_atom}) failed to place piece at (#{row}, #{col}) - invalid placement"
        )

        {:reply, {:error, :invalid_placement}, state}
    end
  end

  @impl true
  def handle_call({:update_name, player_id, new_name}, _from, state) do
    case Map.get(state.players, player_id) do
      nil ->
        {:reply, {:error, :player_not_found}, state}

      player ->
        renamed_player = Player.rename(player, new_name)
        new_players = Map.put(state.players, player_id, renamed_player)
        new_state = %{state | players: new_players}

        Phoenix.PubSub.broadcast(
          BlocTheLine.PubSub,
          "room:#{state.room_code}",
          {:player_name_changed, player_id, new_name}
        )

        Logger.info("Player #{player_id} renamed to #{new_name} in room #{state.room_code}")

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:get_board, _from, state) do
    {:reply, state.board, state}
  end

  @impl true
  def handle_call({:set_public, public}, _from, state) do
    new_state = %{state | public: public}

    # Broadcast to a global topic so lobby/listeners can update
    Phoenix.PubSub.broadcast(
      BlocTheLine.PubSub,
      "public_rooms",
      {:room_public_changed, state.room_code, public}
    )

    # Also notify clients listening to the room topic
    Phoenix.PubSub.broadcast(
      BlocTheLine.PubSub,
      "room:#{state.room_code}",
      {:public_changed, public}
    )

    Logger.info("Room #{state.room_code} public=#{public}")
    {:reply, :ok, new_state}
  end

  # ! IMPORTANT: Function only works if the user is certified to be in the room.
  # I didn't want to dive too much into refactoring, so just a quick note
  # TODO: remove ANCHOR from this function
  @impl true
  def handle_call({:update_position, player_id, piece_name, coord, cells, _anchor}, _from, state) do
    player = Map.get(state.players, player_id)
    piece = piece_name |> String.to_atom() |> Pieces.get()
    new_player =
      player
      |> Player.update_board_location(coord)
      |> Player.set_current_piece(piece)

    new_state = %{state |
      players: Map.replace(state.players, player_id, new_player)
    }

    Phoenix.PubSub.broadcast(
      BlocTheLine.PubSub,
      "room:#{state.room_code}",
      {:position_updated, player_id, piece_name, coord, cells, piece.anchor}
    )

    {:reply, :ok, new_state}
  end

  # Gets the piece the player is currently with
  @impl true
  def handle_call({:get_assigned_piece, player_id}, _from, state) do
    player = Map.get(state.players, player_id)
    {:reply, player.current_piece.name, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    case Map.pop(state.monitors, ref) do
      {nil, _monitors} ->
        {:noreply, state}

      {player_id, monitors} ->
        # remove player_refs entry
        {_, player_refs} = Map.pop(state.player_refs, player_id)

        {player, new_players} = Map.pop(state.players, player_id)

        Logger.debug(
          "Received DOWN for ref=#{inspect(ref)} removing player_id=#{inspect(player_id)} player=#{inspect(player && player.name)}"
        )

        new_state = %{state | players: new_players, monitors: monitors, player_refs: player_refs}

        if player do
          Phoenix.PubSub.broadcast(
            BlocTheLine.PubSub,
            "room:#{state.room_code}",
            {:player_left, player}
          )

          Logger.info("Player #{player.name} left room #{state.room_code} (disconnect)")
        end

        {:noreply, new_state}
    end
  end

  defp via_tuple(room_code) do
    {:via, Registry, {BlocTheLine.RoomRegistry, room_code}}
  end

  # Convert player color (1-4) to player atom (:p1, :p2, :p3, :p4)
  defp color_to_player(1), do: :p1
  defp color_to_player(2), do: :p2
  defp color_to_player(3), do: :p3
  defp color_to_player(4), do: :p4

  # Assign corners to players based on player count
  # Returns a map from player_id to a corner coordinate
  defp assign_corners_to_players(players) do
    player_count = map_size(players)

    corners =
      case player_count do
        # TODO: Change this to use the board size instead
        # Opposite corners for 2 players
        2 -> [{0, 0}, {19, 19}]
        # Three corners, avoiding one
        3 -> [{0, 0}, {19, 0}, {0, 19}]
        # All four corners
        _ -> [{0, 0}, {19, 0}, {0, 19}, {19, 19}]
      end

    players
    |> Enum.sort_by(fn {_id, player} -> player.color end)
    |> Enum.with_index()
    |> Enum.into(%{}, fn {{player_id, _player}, index} ->
      {player_id, Enum.at(corners, index)}
    end)
  end

  # Convert cells from JS format to a Piece struct
  defp cells_to_piece(cells) do
    cell_set =
      cells
      |> Enum.map(fn [x, y] -> {x, y} end)
      |> MapSet.new()

    %Piece{
      name: "custom",
      cells: cell_set,
      corners: cell_set,
      anchor: {0, 0}
    }
  end
end
