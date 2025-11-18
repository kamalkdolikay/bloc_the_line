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
      board: init_empty_board(),
      created_at: DateTime.utc_now(),
      game_started: false,
      next_player_color: 1
    }

    Logger.info("Room #{room_code} created")
    {:ok, state}
  end

  defp init_empty_board() do
    for _ <- 1..20, do: for(_ <- 1..20, do: 0)
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
        |> Map.put(:next_player_color, rem(player_color, 4) + 1) # cycle the color

      Phoenix.PubSub.broadcast(
        BlocTheLine.PubSub,
        "room:#{state.room_code}",
        {:player_joined, new_player}
      )

      Logger.info("Player #{player_name} (#{player_id}) joined room #{state.room_code} as color #{player_color}")
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
    new_board = update_board_with_piece(state.board, row, col, cells, player_color)
    new_state = %{state | board: new_board}

    Phoenix.PubSub.broadcast(
      BlocTheLine.PubSub,
      "room:#{state.room_code}",
      {:piece_placed, player_id, row, col, cells, new_board}
    )

    Logger.info("#{player_id} (color #{player_color}) placed piece at (#{row}, #{col}) in room #{state.room_code}")
    {:reply, {:ok, new_board}, new_state}
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
