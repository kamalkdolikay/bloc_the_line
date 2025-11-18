defmodule BlocTheLineWeb.LobbyLive do
  use BlocTheLineWeb, :live_view
  alias BlocTheLine.Rooms

  def mount(params, _session, socket) do
    # allow pre-filling the room_code from query params when navigating from public list
    room_code = params["room_code"] || ""

    socket =
      socket
      |> assign(:room_code, room_code)
      |> assign(:player_name, "")
      |> assign(:prefill_notice, if(room_code != "", do: "Enter your name to join room #{room_code}", else: nil))

    # subscribe to public rooms updates when connected
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BlocTheLine.PubSub, "public_rooms")
    end

    # initial public rooms list
    {:ok, assign(socket, :public_rooms, Rooms.list_public_rooms())}
  end



  def handle_event("create_room", %{"player_name" => player_name}, socket) do
    player_name = String.trim(player_name)

    # rely on browser `required` validation; if empty, do nothing server-side
    if player_name == "" do
      {:noreply, socket}
    else
      case Rooms.create_room() do
        {:ok, room_code} ->
          {:noreply,
           push_navigate(socket,
             to: ~p"/room/#{room_code}?name=#{player_name}"
           )}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to create room")}
      end
    end
  end

  def handle_info({:room_public_changed, _room_code, _public}, socket) do
    {:noreply, assign(socket, :public_rooms, Rooms.list_public_rooms())}
  end

  def handle_event("join_room", %{"room_code" => room_code, "player_name" => player_name}, socket) do
    room_code = String.trim(room_code) |> String.upcase()
    player_name = String.trim(player_name)

    # rely on browser `required` validation for empty fields
    if player_name == "" or room_code == "" do
      {:noreply, socket}
    else
      if not Rooms.room_exists?(room_code) do
        {:noreply, put_flash(socket, :error, "Room not found")}
      else
        {:noreply,
         push_navigate(socket,
           to: ~p"/room/#{room_code}?name=#{player_name}"
         )}
      end
    end
  end

  def handle_event("update_room_code", %{"room_code" => value}, socket) do
    {:noreply, assign(socket, :room_code, String.upcase(value))}
  end

  def handle_event("update_player_name", %{"player_name" => value}, socket) do
    {:noreply, assign(socket, :player_name, value)}
  end
end
