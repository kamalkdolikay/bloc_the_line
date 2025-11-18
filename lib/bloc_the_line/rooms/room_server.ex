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

  def set_public(room_code, public) when is_boolean(public) do
    GenServer.call(via_tuple(room_code), {:set_public, public})
  end

  @impl true
  def init(room_code) do
    state = %{
      room_code: room_code,
      players: %{},
      created_at: DateTime.utc_now(),
      game_started: false,
      public: false
    }

    Logger.info("Room #{room_code} created")
    {:ok, state}
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

  defp via_tuple(room_code) do
    {:via, Registry, {BlocTheLine.RoomRegistry, room_code}}
  end

  defp generate_player_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
