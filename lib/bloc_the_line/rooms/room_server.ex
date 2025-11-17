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

  def start_game(room_code) do
    GenServer.call(via_tuple(room_code), :start_game)
  end

  @impl true
  def init(room_code) do
    # Initialize a 5x5 board for the lobby phase
    board = for _ <- 1..5, do: for(_ <- 1..5, do: 0)

    state = %{
      room_code: room_code,
      players: %{},
      board: board,
      created_at: DateTime.utc_now(),
      game_started: false
    }

    Logger.info("Room #{room_code} created")
    {:ok, state}
  end

  @impl true
  def handle_call(:start_game, _from, state) do
    if state.game_started do
      {:reply, {:error, :already_started}, state}
    else
      # Switch to 20x20 board for the actual game
      new_board = for _ <- 1..20, do: for(_ <- 1..20, do: 0)
      new_state = %{state | game_started: true, board: new_board}

      Phoenix.PubSub.broadcast(
        BlocTheLine.PubSub,
        "room:#{state.room_code}",
        {:game_started, new_board}
      )

      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:join, player_name}, _from, state) do
    player_id = generate_player_id()

    new_player = %{
      id: player_id,
      name: player_name,
      joined_at: DateTime.utc_now()
    }

    new_state = put_in(state.players[player_id], new_player)

    Phoenix.PubSub.broadcast(
      BlocTheLine.PubSub,
      "room:#{state.room_code}",
      {:player_joined, new_player}
    )

    Logger.info("Player #{player_name} (#{player_id}) joined room #{state.room_code}")
    {:reply, {:ok, player_id}, new_state}
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

  defp via_tuple(room_code) do
    {:via, Registry, {BlocTheLine.RoomRegistry, room_code}}
  end

  defp generate_player_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
