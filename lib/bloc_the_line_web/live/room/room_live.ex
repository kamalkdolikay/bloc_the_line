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
          {:ok, room_state} = Rooms.get_room(room_code)
          board = for _ <- 1..5, do: for(_ <- 1..5, do: 0)

          {:ok,
           socket
           |> assign(:room_code, room_code)
           |> assign(:player_id, player_id)
           |> assign(:player_name, player_name)
           |> assign(:players, room_state.players)
           |> assign(:board, board)
           |> assign(:copied, false)}

        {:error, :room_not_found} ->
          {:ok,
           socket
           |> put_flash(:error, "Room not found")
           |> push_navigate(to: ~p"/")}
      end
    else
      board = for _ <- 1..5, do: for(_ <- 1..5, do: 0)

      {:ok,
       socket
       |> assign(:room_code, room_code)
       |> assign(:player_id, nil)
       |> assign(:player_name, player_name)
       |> assign(:players, %{})
       |> assign(:board, board)
       |> assign(:copied, false)}
    end
  end

  def handle_event("cell_click", %{"row" => r, "col" => c}, socket) do
    row = String.to_integer(r)
    col = String.to_integer(c)

    IO.inspect({row, col}, label: "Cell clicked by #{socket.assigns.player_name}")

    # update the board (scuffed board state)
    board =
      socket.assigns.board
      |> List.update_at(row, fn row_list ->
        List.update_at(row_list, col, fn _ -> 1 end)
      end)

    Phoenix.PubSub.broadcast(
      BlocTheLine.PubSub,
      "room:#{socket.assigns.room_code}",
      {:cell_clicked, socket.assigns.player_id, row, col}
    )

    {:noreply, assign(socket, :board, board)}
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

  def terminate(_reason, socket) do
    if socket.assigns[:player_id],
      do: Rooms.leave_room(socket.assigns.room_code, socket.assigns.player_id)

    :ok
  end
end
