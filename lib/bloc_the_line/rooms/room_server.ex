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

  @impl true
  def init(room_code) do
    state = %{
      room_code: room_code,
      players: %{},
      board: Board.new(20, 20, 4),
      created_at: DateTime.utc_now(),
      game_started: false,
      next_player_color: 1
    }

    Logger.info("Room #{room_code} created")
    {:ok, state}
  end

  @impl true
  def handle_call({:join, player_name}, _from, state) do
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

      new_state =
        state
        |> put_in([:players, player_id], new_player)
        # cycle the color
        |> Map.put(:next_player_color, rem(player_color, 4) + 1)

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
    new_state = %{state | players: new_players}

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
    player_atom = color_to_player(player_color)

    # Convert cells to a Piece struct
    piece = cells_to_piece(cells)

    # Use Board.add_piece with validation
    case Board.add_piece(state.board, piece, {col, row}, player_atom) do
      {:ok, new_board} ->
        new_state = %{state | board: new_board}

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

  defp via_tuple(room_code) do
    {:via, Registry, {BlocTheLine.RoomRegistry, room_code}}
  end

  defp generate_player_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
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
