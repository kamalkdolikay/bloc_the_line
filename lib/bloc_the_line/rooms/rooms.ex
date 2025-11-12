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

  def list_players(room_code) do
    RoomServer.list_players(room_code)
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
