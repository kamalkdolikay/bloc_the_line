defmodule BlocTheLine.Rooms.RoomServer do
  use GenServer
  require Logger
  alias Pieces
  alias Player
  alias GameTimer

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

  @impl true
  def init(room_code) do
    state = %{
      room_code: room_code,
      players: %{},
      board: Board.new(20, 20, 4),
      created_at: DateTime.utc_now(),
      game_started: false,
      game_over: false,
      next_player_color: 1,
      public: false,
      # ref => player_id
      monitors: %{},
      # player_id => ref
      player_refs: %{},
      # player_id => {col, row} corner assignment
      player_corners: %{},
      # player_id => %{piece: :F, coord: {3, 5}}
      player_positions: %{},
      # player_id => piece_name (e.g. "L4")
      player_pieces: %{},
      # game timer reference
      timer_ref: nil
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
          player_id = generate_player_id()
          player_color = state.next_player_color

          joined_at = DateTime.utc_now()

          # Player model (board_location/start_location will be set when game starts)
          player_model = Player.new(player_name, {0, 0})

          new_player = %{
            id: player_id,
            name: player_name,
            color: player_color,
            ready: false,
            joined_at: joined_at,
            model: player_model
          }

          ref = Process.monitor(from_pid)

          Logger.debug(
            "Monitoring pid=#{inspect(from_pid)} ref=#{inspect(ref)} for player=#{player_id}"
          )

          monitors = Map.put(state.monitors, ref, player_id)
          player_refs = Map.put(state.player_refs, player_id, ref)

          new_state =
            state
            |> put_in([:players, player_id], new_player)
            # cycle the color
            |> Map.put(:next_player_color, rem(player_color, 4) + 1)
            |> Map.put(:monitors, monitors)
            |> Map.put(:player_refs, player_refs)

          # Assign host_id if this is the first player
          new_state =
            if map_size(state.players) == 0 do
              Map.put(new_state, :host_id, player_id)
            else
              new_state
            end

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
    # Assign corners & update player models
    {player_corners, updated_players} = assign_corners_to_players(state.players)

    # Cancel previous timer if any
    GameTimer.cancel_timer(state.timer_ref)
    timer_ref = GameTimer.start_timer()

    new_pieces =
      updated_players
      |> Map.keys()
      |> Enum.reduce(%{}, fn player_id, acc ->
        random_piece = Pieces.random_starting_piece_name()
        Map.put(acc, player_id, random_piece)
      end)

    updated_players_with_models =
      Enum.reduce(new_pieces, updated_players, fn {player_id, piece_name}, acc ->
        player = acc[player_id]
        updated_model = %Player{player.model | current_piece: piece_name}
        Map.put(acc, player_id, %{player | model: updated_model})
      end)

    new_state = %{
      state
      | game_started: true,
        game_over: false,
        player_corners: player_corners,
        player_pieces: new_pieces,
        players: updated_players_with_models,
        timer_ref: timer_ref
    }

    # Broadcast starting piece to each player
    Enum.each(new_pieces, fn {player_id, piece_name} ->
      Phoenix.PubSub.broadcast(
        BlocTheLine.PubSub,
        "room:#{state.room_code}",
        {:piece_assigned, player_id, piece_name}
      )

      # Broadcast model update so HEEx updates Held UI
      Phoenix.PubSub.broadcast(
        BlocTheLine.PubSub,
        "room:#{state.room_code}",
        {:player_updated, player_id, updated_players_with_models[player_id]}
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

  def handle_call({:place_piece, player_id, row, col, cells}, _from, state) do
    if state.game_over do
      {:reply, {:error, :game_over}, state}
    else
      player = Map.fetch!(state.players, player_id)
      player_color = player.color || 1
      player_atom = color_to_player(player_color)
      player_corner = Map.get(state.player_corners, player_id)

      piece = cells_to_piece(cells)

      case Board.add_piece(state.board, piece, {col, row}, player_atom, player_corner) do
        {:ok, new_board} ->
          random_piece = Pieces.random_starting_piece_name()

          updated_model =
            player.model
            |> Player.add_points_by_piece(piece)      # score update
            |> Map.put(:current_piece, random_piece)  # update held piece

          updated_player = %{player | model: updated_model}

          updated_players =
            Map.put(state.players, player_id, updated_player)

          # Update player_pieces map
          new_player_pieces =
            Map.put(state.player_pieces, player_id, random_piece)

          new_state = %{
            state
            | board: new_board,
              players: updated_players,
              player_pieces: new_player_pieces
          }
          Phoenix.PubSub.broadcast(
            BlocTheLine.PubSub,
            "room:#{state.room_code}",
            {:piece_placed, player_id, row, col, cells, new_board}
          )

          Phoenix.PubSub.broadcast(
            BlocTheLine.PubSub,
            "room:#{state.room_code}",
            {:piece_assigned, player_id, random_piece}
          )

          Phoenix.PubSub.broadcast(
            BlocTheLine.PubSub,
            "room:#{state.room_code}",
            {:scores_updated, compute_scores(updated_players)}
          )

          Phoenix.PubSub.broadcast(
            BlocTheLine.PubSub,
            "room:#{state.room_code}",
            {:player_updated, player_id, updated_player}
          )

          Logger.info(
            "#{player_id} (#{player_atom}) placed piece at (#{row}, #{col}) in room #{state.room_code}"
          )

          {:reply, {:ok, new_board}, new_state}

        {:err, _board} ->
          Logger.warning(
            "#{player_id} (#{player_atom}) failed to place piece - invalid placement"
          )

          {:reply, {:error, :invalid_placement}, state}
      end
    end
  end



  @impl true
  def handle_call({:update_name, player_id, new_name}, _from, state) do
    case Map.get(state.players, player_id) do
      nil ->
        {:reply, {:error, :player_not_found}, state}

      player ->
        updated_model = %Player{player.model | name: new_name}
        updated_player = %{player | name: new_name, model: updated_model}
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
  def handle_call({:update_position, player_id, piece, coord, cells, anchor}, _from, state) do
    new_positions =
      Map.put(state.player_positions, player_id, %{
        piece: piece,
        coord: coord,
        cells: cells,
        anchor: anchor
      })

    new_state = %{state | player_positions: new_positions}

    Phoenix.PubSub.broadcast(
      BlocTheLine.PubSub,
      "room:#{state.room_code}",
      {:position_updated, player_id, piece, coord, cells, anchor}
    )

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_assigned_piece, player_id}, _from, state) do
    piece_name = Map.get(state.player_pieces, player_id)
    {:reply, piece_name, state}
  end

  @impl true
  def handle_info(:game_over_timeout, state) do
    # Prevent double-processing if somehow fired after already marked game_over
    if state.game_over do
      {:noreply, state}
    else
      scores = compute_scores(state.players)
      winner_id = compute_winner(state.players)

      Logger.info(
        "Game over by timer in room #{state.room_code}, winner=#{inspect(winner_id)} scores=#{inspect(scores)}"
      )

      Phoenix.PubSub.broadcast(
        BlocTheLine.PubSub,
        "room:#{state.room_code}",
        {:game_over, winner_id, scores}
      )

      {:noreply, %{state | game_over: true, timer_ref: nil}}
    end
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

  # Convert player color to player atom (:p1, :p2, :p3, :p4)
  defp color_to_player(1), do: :p1
  defp color_to_player(2), do: :p2
  defp color_to_player(3), do: :p3
  defp color_to_player(4), do: :p4

  defp assign_corners_to_players(players) do
    player_count = map_size(players)

    corners =
      case player_count do
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
    |> Enum.reduce({%{}, players}, fn {{player_id, player}, index},
                                      {corner_map, players_acc} ->
      corner = Enum.at(corners, index)

      updated_model = %Player{
        player.model
        | start_location: corner,
          board_location: corner
      }

      updated_player = %{player | model: updated_model}

      {
        Map.put(corner_map, player_id, corner),
        Map.put(players_acc, player_id, updated_player)
      }
    end)
  end

  defp compute_scores(players) do
    players
    |> Enum.into(%{}, fn {id, player} ->
      {id, player.model.points}
    end)
  end

  defp compute_winner(players) do
    players
    |> Enum.max_by(fn {_id, player} -> player.model.points end, fn -> {nil, %{model: %{points: 0}}} end)
    |> elem(0)
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
