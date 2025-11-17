defmodule BlocTheLineWeb.RoomLive do
  use BlocTheLineWeb, :live_view
  alias BlocTheLine.Rooms

  def mount(params, _session, socket) do
    room_code = params["room_code"]
    player_name = params["name"] || "Guest"

    if connected?(socket) do
      case Rooms.join_room(room_code, player_name) do
        {:ok, player_id} ->
          Phoenix.PubSub.subscribe(BlocTheLine.PubSub, "room:#{room_code}")
          # Fetch full state including board and game_started
          {:ok, room_state} = Rooms.get_room(room_code)

          {:ok,
           socket
           |> assign(:room_code, room_code)
           |> assign(:player_id, player_id)
           |> assign(:player_name, player_name)
           |> assign(:players, room_state.players)
           |> assign(:board, room_state.board)
           |> assign(:game_started, room_state.game_started)
           |> assign(:copied, false)}

        {:error, :room_not_found} ->
          {:ok,
           socket
           |> put_flash(:error, "Room not found")
           |> push_navigate(to: ~p"/")}
      end
    else
      # Initial placeholder state for disconnected mount
      board = for _ <- 1..5, do: for(_ <- 1..5, do: 0)

      {:ok,
       socket
       |> assign(:room_code, room_code)
       |> assign(:player_id, nil)
       |> assign(:player_name, player_name)
       |> assign(:players, %{})
       |> assign(:board, board) # Use the actual 5x5 structure here
       |> assign(:game_started, false)
       |> assign(:copied, false)}
    end
  end

  def handle_event("cell_click", %{"row" => r, "col" => c}, socket) do
    if not socket.assigns.game_started do
      # If game hasn't started, clicking the board starts it
      Rooms.start_game(socket.assigns.room_code)
      {:noreply, socket}
    else

      row = String.to_integer(r)
      col = String.to_integer(c)
      IO.inspect({row, col}, label: "Game Board Clicked")

      {:noreply, socket}
    end
  end


  def handle_event("copy_link", _params, socket) do
    {:noreply, assign(socket, :copied, true)}
  end

  def handle_event("reset_copied", _params, socket) do
    {:noreply, assign(socket, :copied, false)}
  end

  def handle_info({:player_joined, player}, socket) do
    {:noreply, assign(socket, :players, Map.put(socket.assigns.players, player.id, player))}
  end

  def handle_info({:player_left, player}, socket) do
    {:noreply, assign(socket, :players, Map.delete(socket.assigns.players, player.id))}
  end

  def handle_info({:cell_clicked, _player_id, row, col}, socket) do
    board =
      socket.assigns.board
      |> List.update_at(row, fn row_list ->
        List.update_at(row_list, col, fn _ -> 1 end)
      end)

    {:noreply, assign(socket, :board, board)}
  end

  def handle_info({:game_started, new_board}, socket) do
    {:noreply,
     socket
     |> assign(:game_started, true)
     |> assign(:board, new_board)}
  end

  def terminate(_reason, socket) do
    if socket.assigns[:player_id],
      do: Rooms.leave_room(socket.assigns.room_code, socket.assigns.player_id)

    :ok
  end
end
