defmodule BlocTheLine.Rooms.RoomSupervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_room(room_code) do
    spec = {BlocTheLine.Rooms.RoomServer, room_code}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_room(room_code) do
    case Registry.lookup(BlocTheLine.RoomRegistry, room_code) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_found}
    end
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
