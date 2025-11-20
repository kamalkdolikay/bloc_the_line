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
      |> assign(
        :prefill_notice,
        if(room_code != "", do: "Enter your name to join room #{room_code}", else: nil)
      )

    # subscribe to public rooms updates when connected
    if connected?(socket) do
      Phoenix.PubSub.subscribe(BlocTheLine.PubSub, "public_rooms")
    end

    # initial public rooms list
    {:ok, assign(socket, :public_rooms, Rooms.list_public_rooms())}
  end

  # Update assigns when query params change (e.g. when clicking Join on a public room)
  def handle_params(params, _uri, socket) do
    room_code = params["room_code"] || ""

    socket =
      socket
      |> assign(:room_code, room_code)
      |> assign(
        :prefill_notice,
        if(room_code != "", do: "Enter your name to join room #{room_code}", else: nil)
      )

    {:noreply, socket}
  end

  def handle_event("create_room", %{"player_name" => player_name}, socket) do
    player_name = String.trim(player_name)

    # rely on browser `required` validation; if empty, show an error
    if player_name == "" do
      {:noreply, put_flash(socket, :error, "Please enter your name")}
    else
      case Rooms.create_room() do
        {:ok, room_code} ->
            {:noreply,
             push_navigate(socket,
               to: ~p"/room/#{room_code}?name=#{URI.encode_www_form(player_name)}"
             )}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to create room")}
      end
    end
  end

  def handle_event("join_room", %{"room_code" => room_code, "player_name" => player_name}, socket) do
    room_code = String.trim(room_code) |> String.upcase()
    player_name = String.trim(player_name)

    # Debug: log received params for diagnosis
    IO.inspect(%{recv_params: %{room_code: room_code, player_name: player_name}},
      label: "DEBUG join_room"
    )

    if room_code == "" do
      {:noreply, put_flash(socket, :error, "Please enter a room code")}
    else
      # Require a non-empty player name; do not auto-generate guest names here.
      if player_name == "" do
        {:noreply, put_flash(socket, :error, "Please enter your name")}
      else
          {:noreply,
           push_navigate(socket,
             to: ~p"/room/#{room_code}?name=#{URI.encode_www_form(player_name)}"
           )}
      end
    end
  end

  def handle_event(
        "join_public",
        %{"room_code" => room_code, "player_name" => param_name},
        socket
      ) do
    room_code = String.trim(room_code) |> String.upcase()

    # Prefer the name passed in the event (bound at render time). If that's
    # empty, fall back to the socket assign. Do NOT generate a guest name here;
    # require the user to provide a name.
    param_name = String.trim(param_name || "")
    current_name = String.trim(socket.assigns[:player_name] || "")

    chosen_name =
      cond do
        param_name != "" -> param_name
        current_name != "" -> current_name
        true -> nil
      end

    if chosen_name == nil do
      {:noreply, put_flash(socket, :error, "Please enter your name before joining a public room")}
    else
        {:noreply,
         push_navigate(socket,
           to: ~p"/room/#{room_code}?name=#{URI.encode_www_form(chosen_name)}"
         )}
    end
  end

  def handle_event("update_room_code", %{"room_code" => value}, socket) do
    {:noreply, assign(socket, :room_code, String.upcase(value))}
  end

  def handle_event("update_player_name", %{"player_name" => value}, socket) do
    {:noreply, assign(socket, :player_name, value)}
  end

  def handle_info({:room_public_changed, _room_code, _public}, socket) do
    {:noreply, assign(socket, :public_rooms, Rooms.list_public_rooms())}
  end
end
