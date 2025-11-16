defmodule BlocTheLineWeb.LobbyLive do
  use BlocTheLineWeb, :live_view
  alias BlocTheLine.Rooms

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:room_code, "")
     |> assign(:player_name, "")
     |> assign(:error, nil)}
  end

  def handle_event("create_room", %{"player_name" => player_name}, socket) do
    player_name = String.trim(player_name)

    if player_name == "" do
      {:noreply, assign(socket, :error, "Please enter your name")}
    else
      case Rooms.create_room() do
        {:ok, room_code} ->
          {:noreply,
           push_navigate(socket,
             to: ~p"/room/#{room_code}?name=#{player_name}"
           )}

        {:error, _} ->
          {:noreply, assign(socket, :error, "Failed to create room")}
      end
    end
  end

  def handle_event("join_room", %{"room_code" => room_code, "player_name" => player_name}, socket) do
    room_code = String.trim(room_code) |> String.upcase()
    player_name = String.trim(player_name)

    cond do
      player_name == "" ->
        {:noreply, assign(socket, :error, "Please enter your name")}

      room_code == "" ->
        {:noreply, assign(socket, :error, "Please enter a room code")}

      not Rooms.room_exists?(room_code) ->
        {:noreply, assign(socket, :error, "Room not found")}

      true ->
        {:noreply,
         push_navigate(socket,
           to: ~p"/room/#{room_code}?name=#{player_name}"
         )}
    end
  end

  def handle_event("update_room_code", %{"room_code" => value}, socket) do
    {:noreply, assign(socket, :room_code, String.upcase(value))}
  end

  def handle_event("update_player_name", %{"player_name" => value}, socket) do
    {:noreply, assign(socket, :player_name, value)}
  end
end
