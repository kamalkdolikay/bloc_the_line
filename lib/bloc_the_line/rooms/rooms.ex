defmodule BlocTheLine.Rooms do
  alias BlocTheLine.Rooms.{RoomServer, RoomSupervisor}

  def create_room do
    room_code = generate_room_code()

    case RoomSupervisor.start_room(room_code) do
      {:ok, _pid} -> {:ok, room_code}
      # uses different code
      {:error, {:already_started, _pid}} -> create_room()
      error -> error
    end
  end

  def reset_room(room_code) do
    RoomServer.reset(room_code)
  end

  def join_room(room_code, player_name) do
    case room_exists?(room_code) do
      true ->
        RoomServer.join(room_code, player_name)

      false ->
        # Try to start the room dynamically and then join. This makes joining
        # idempotent from the caller's perspective (no "room not found" errors).
        case RoomSupervisor.start_room(room_code) do
          {:ok, _pid} -> RoomServer.join(room_code, player_name)
          {:error, {:already_started, _pid}} -> RoomServer.join(room_code, player_name)
          _ -> {:error, :room_not_found}
        end
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

  # updates the players position
  def update_position(room_code, player_id, piece, coord, cells, anchor) do
    case room_exists?(room_code) do
      true -> RoomServer.update_position(room_code, player_id, piece, coord, cells, anchor)
      false -> {:error, :room_not_found}
    end
  end

  def get_board(room_code) do
    RoomServer.get_board(room_code)
  end

  def update_player_name(room_code, player_id, new_name) do
    RoomServer.update_player_name(room_code, player_id, new_name)
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

  # Sets the room as ready
  def set_ready(room_code, player_id, ready) do
    RoomServer.set_ready(room_code, player_id, ready)
  end

  def start_game(room_code) do
    RoomServer.start_game(room_code)
  end

  def get_assigned_piece(room_code, player_id) do
    case room_exists?(room_code) do
      true -> RoomServer.get_assigned_piece(room_code, player_id)
      false -> nil
    end
  end
end
