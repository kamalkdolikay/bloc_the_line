defmodule BlocTheLine.Rooms.RoomServer do
  use GenServer
  require Logger

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

  def update_position(room_code, player_id, piece, coord) when is_tuple(coord) do
    GenServer.call(via_tuple(room_code), {:update_position, player_id, piece, coord})
  end

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
      player_refs: %{},
      # TODO: will take this out as each player will have this information instead
      # player_id => %{piece: :F, coord: {3, 5}}
      player_positions: %{}
    }

    Logger.info("Room #{room_code} created")
    {:ok, state}
  end

  @impl true
  def handle_call({:join, player_name}, {from_pid, _ref} = _from, state) do
    if map_size(state.players) >= 4 do
      {:reply, {:error, :room_full}, state}
    else
      new_player = Player.new(
        player_name,
        state.next_player_color,
        {0, 0},        # TODO: add that players' corner
        DateTime.utc_now()
      )

      # Monitor the caller process so we can remove the player on disconnect
      ref = Process.monitor(from_pid)

      Logger.debug(
        "Monitoring pid=#{inspect(from_pid)} ref=#{inspect(ref)} for player=#{new_player.id}"
      )

      # record the monitor ref -> new_player.id and new_player.id -> ref so we can cleanup on DOWN
      monitors = Map.put(state.monitors, ref, new_player.id)
      player_refs = Map.put(state.player_refs, new_player.id, ref)

      new_state =
        state
        |> put_in([:players, new_player.id], new_player)
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

  # Setter the player's ready variable
  @impl true
  def handle_call({:set_ready, player_id, ready}, _from, state) do
    new_state = update_in(state.players[player_id].ready, fn _ -> ready end)

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
    new_state = %{state | game_started: true}

    Phoenix.PubSub.broadcast(
      BlocTheLine.PubSub,
      "room:#{state.room_code}",
      {:game_started}
    )

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:leave, player_id}, _from, state) do
    {player, new_players} = Map.pop(state.players, player_id)

    # If the leaving player is the host, assign host_id to the next player (if any)
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

  @impl true
  def handle_call({:place_piece, player_id, row, col, cells}, _from, state) do
    player_color = get_in(state.players, [player_id, :color]) || 1
    player_atom = color_to_player(player_color)

    # Convert cells to a Piece struct
    # TODO: Maybe use a function to transform into the pre chosen pieces
    piece = cells_to_piece(cells)

    # Use Board.add_piece with validation
    case Board.add_piece(state.board, piece, {col, row}, player_atom) do
      {:ok, new_board} ->
        new_state = %{state | board: new_board}

        # TODO: Update player points/score

        # TODO: Check player struct broadcasts
        Phoenix.PubSub.broadcast(
          BlocTheLine.PubSub,
          "room:#{state.room_code}",
          {:piece_placed, player_id, row, col, cells, new_board}
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

  @impl true
  def handle_call({:update_position, player_id, piece, coord}, _from, state) do
    new_positions =
      Map.put(state.player_positions, player_id, %{
        piece: piece,
        coord: coord
      })

    new_state = %{state | player_positions: new_positions}

    Phoenix.PubSub.broadcast(
      BlocTheLine.PubSub,
      "room:#{state.room_code}",
      {:position_updated, player_id, piece, coord}
    )

    {:reply, :ok, new_state}
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
