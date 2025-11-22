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

  def update_player_name(room_code, player_id, new_name) do
    GenServer.call(via_tuple(room_code), {:update_name, player_id, new_name})
  end

  def get_board(room_code) do
    GenServer.call(via_tuple(room_code), :get_board)
  end

  def set_public(room_code, public) when is_boolean(public) do
    GenServer.call(via_tuple(room_code), {:set_public, public})
  end

  @impl true
  def init(room_code) do
    state = %{
      room_code: room_code,
      players: %{},
      board: init_empty_board(),
      created_at: DateTime.utc_now(),
      game_started: false,
      next_player_color: 1,
      public: false,
      # ref => player_id
      monitors: %{},
      # player_id => ref
      player_refs: %{}
    }

    Logger.info("Room #{room_code} created")
    {:ok, state}
  end

  defp init_empty_board() do
    for _ <- 1..20, do: for(_ <- 1..20, do: 0)
  end

  @impl true
  def handle_call({:join, player_name}, {from_pid, _ref} = _from, state) do
    if map_size(state.players) >= 4 do
      {:reply, {:error, :room_full}, state}
    else
      player_id = generate_player_id()
      player_color = state.next_player_color

      new_player = %{
        id: player_id,
        name: player_name,
        color: player_color,
        joined_at: DateTime.utc_now()
      }

      # Monitor the caller process so we can remove the player on disconnect
      ref = Process.monitor(from_pid)

      Logger.debug(
        "Monitoring pid=#{inspect(from_pid)} ref=#{inspect(ref)} for player=#{player_id}"
      )

      # record the monitor ref -> player_id and player_id -> ref so we can cleanup on DOWN
      monitors = Map.put(state.monitors, ref, player_id)
      player_refs = Map.put(state.player_refs, player_id, ref)

      new_state =
        state
        |> put_in([:players, player_id], new_player)
        |> Map.put(:next_player_color, rem(player_color, 4) + 1) # cycle the color
        |> Map.put(:monitors, monitors)
        |> Map.put(:player_refs, player_refs)

      Phoenix.PubSub.broadcast(
        BlocTheLine.PubSub,
        "room:#{state.room_code}",
        {:player_joined, new_player}
      )

      Logger.info(
        "Player #{player_name} (#{player_id}) joined room #{state.room_code} as color #{player_color}"
      )

      {:reply, {:ok, player_id}, new_state}
    end
  end

  @impl true
  def handle_call({:leave, player_id}, _from, state) do
    {player, new_players} = Map.pop(state.players, player_id)
    # demonitor if we were tracking this player
    {ref, player_refs} = Map.pop(state.player_refs, player_id)
    monitors = if ref, do: Map.delete(state.monitors, ref), else: state.monitors

    if ref do
      Logger.debug("Demonitoring ref=#{inspect(ref)} for player=#{player_id}")

      try do
        Process.demonitor(ref, [:flush])
      rescue
        _ -> :ok
      end
    end

    new_state = %{state | players: new_players, monitors: monitors, player_refs: player_refs}

    if player do
      Phoenix.PubSub.broadcast(
        BlocTheLine.PubSub,
        "room:#{state.room_code}",
        {:player_left, player}
      )

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
    new_board = update_board_with_piece(state.board, row, col, cells, player_color)
    new_state = %{state | board: new_board}

    Phoenix.PubSub.broadcast(
      BlocTheLine.PubSub,
      "room:#{state.room_code}",
      {:piece_placed, player_id, row, col, cells, new_board}
    )

    Logger.info(
      "#{player_id} (color #{player_color}) placed piece at (#{row}, #{col}) in room #{state.room_code}"
    )

    {:reply, {:ok, new_board}, new_state}
  end

  @impl true
  def handle_call({:update_name, player_id, new_name}, _from, state) do
    case Map.get(state.players, player_id) do
      nil ->
        {:reply, {:error, :player_not_found}, state}

      player ->
        updated_player = Map.put(player, :name, new_name)
        new_players = Map.put(state.players, player_id, updated_player)
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

  defp generate_player_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end

  defp update_board_with_piece(board, row, col, cells, player_color) do
    IO.inspect(cells, label: "DEBUG: cells being placed")
    IO.inspect({row, col}, label: "DEBUG: anchor position")

    Enum.reduce(cells, board, fn [dx, dy], acc_board ->
      target_row = row + dy
      target_col = col + dx

      IO.inspect({target_row, target_col}, label: "DEBUG: placing at")

      # checking the bounds
      if target_row >= 0 and target_row < length(acc_board) and
           target_col >= 0 and target_col < length(Enum.at(acc_board, 0)) do
        List.update_at(acc_board, target_row, fn row_data ->
          List.update_at(row_data, target_col, fn _ -> player_color end)
        end)
      else
        acc_board
      end
    end)
  end


end
