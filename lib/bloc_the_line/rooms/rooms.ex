defmodule BlocTheLine.Rooms do

  alias BlocTheLine.Rooms.{RoomServer, RoomSupervisor}

  def create_room do
    room_code = generate_room_code()

    case RoomSupervisor.start_room(room_code) do
      {:ok, _pid} -> {:ok, room_code}
      {:error, {:already_started, _pid}} -> create_room() # uses different code
      error -> error
    end
  end

  def join_room(room_code, player_name) do
    case room_exists?(room_code) do
      true -> RoomServer.join(room_code, player_name)
      false -> {:error, :room_not_found}
    end
  end

  def leave_room(room_code, player_id) do
    RoomServer.leave(room_code, player_id)
  end

  # get the current state
  def get_room(room_code) do
    case room_exists?(room_code) do
      true -> {:ok, RoomServer.get_state(room_code)}
      false -> {:error, :room_not_found}
    end
  end

  def set_public(room_code, public) when is_boolean(public) do
    case room_exists?(room_code) do
      true -> RoomServer.set_public(room_code, public)
      false -> {:error, :room_not_found}
    end
  end

  @doc """
  Returns a list of public rooms as maps: %{room_code: String.t(), players: [player], created_at: DateTime.t()}
  """
  def list_public_rooms do
    # get all registered room keys from the Registry
    keys = Registry.select(BlocTheLine.RoomRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])

    keys
    |> Enum.uniq()
    |> Enum.map(&RoomServer.get_state/1)
    |> Enum.filter(fn
      %{} = state -> Map.get(state, :public, false)
      _ -> false
    end)
    |> Enum.map(fn state ->
      %{
        room_code: state.room_code,
        players: Map.values(state.players),
        created_at: state.created_at
      }
    end)
  end

  def list_players(room_code) do
    RoomServer.list_players(room_code)
  end

  def place_piece(room_code, player_id, row, col, cells) do
    RoomServer.place_piece(room_code, player_id, row, col, cells)
  end

  def get_board(room_code) do
    RoomServer.get_board(room_code)
  end

  # check if the room exists using registry lookup
  def room_exists?(room_code) do
    case Registry.lookup(BlocTheLine.RoomRegistry, room_code) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  # function that generates 6 digit code
  defp generate_room_code do
    :crypto.strong_rand_bytes(3)
    |> Base.encode16()
    |> String.slice(0, 6)
  end
end
