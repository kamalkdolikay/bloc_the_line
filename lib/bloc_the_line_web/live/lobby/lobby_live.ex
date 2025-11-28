defmodule BlocTheLineWeb.LobbyLive do
  use BlocTheLineWeb, :live_view
  alias BlocTheLine.Rooms

  # Player name validation: alphanumeric, spaces, hyphens, underscores only, 1-30 chars
  defp validate_player_name(name) when is_binary(name) do
    trimmed = String.trim(name)

    cond do
      trimmed == "" ->
        {:error, "Name cannot be empty"}

      String.length(trimmed) > 30 ->
        {:error, "Name must be 30 characters or less"}

      not Regex.match?(~r/^[a-zA-Z0-9\s\-_]+$/, trimmed) ->
        {:error,
         "Name can only contain letters, numbers, spaces, hyphens (-), and underscores (_)"}

      true ->
        {:ok, trimmed}
    end
  end

  defp validate_player_name(_), do: {:error, "Invalid name format"}

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
    trimmed_name = String.trim(player_name)

    # If name is provided, validate it. If empty, allow guest name generation.
    if trimmed_name == "" do
      case Rooms.create_room() do
        {:ok, room_code} ->
          {:noreply, push_navigate(socket, to: ~p"/room/#{room_code}")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to create room")}
      end
    else
      case validate_player_name(player_name) do
        {:ok, validated_name} ->
          case Rooms.create_room() do
            {:ok, room_code} ->
              {:noreply,
               push_navigate(socket,
                 to: ~p"/room/#{room_code}?name=#{URI.encode_www_form(validated_name)}"
               )}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to create room")}
          end

        {:error, message} ->
          {:noreply, put_flash(socket, :error, message)}
      end
    end
  end

  def handle_event("join_room", %{"room_code" => room_code, "player_name" => player_name}, socket) do
    room_code = String.trim(room_code) |> String.upcase()

    if room_code == "" do
      {:noreply, put_flash(socket, :error, "Please enter a room code")}
    else
      trimmed_name = String.trim(player_name)

      # If name is provided, validate it. If empty, allow guest name generation.
      if trimmed_name == "" do
        {:noreply, push_navigate(socket, to: ~p"/room/#{room_code}")}
      else
        case validate_player_name(player_name) do
          {:ok, validated_name} ->
            {:noreply,
             push_navigate(socket,
               to: ~p"/room/#{room_code}?name=#{URI.encode_www_form(validated_name)}"
             )}

          {:error, message} ->
            {:noreply, put_flash(socket, :error, message)}
        end
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

    # If no name provided, allow guest name generation. Otherwise validate the name.
    if chosen_name == nil or String.trim(chosen_name) == "" do
      {:noreply, push_navigate(socket, to: ~p"/room/#{room_code}")}
    else
      case validate_player_name(chosen_name) do
        {:ok, validated_name} ->
          {:noreply,
           push_navigate(socket,
             to: ~p"/room/#{room_code}?name=#{URI.encode_www_form(validated_name)}"
           )}

        {:error, message} ->
          {:noreply, put_flash(socket, :error, message)}
      end
    end
  end

  def handle_event("update_room_code", %{"room_code" => value}, socket) do
    {:noreply, assign(socket, :room_code, String.upcase(value))}
  end

  def handle_event("update_player_name", %{"player_name" => value}, socket) do
    {:noreply, assign(socket, :player_name, value)}
  end

  def handle_event("check_game_started", %{"room_code" => room_code}, socket) do
    game_started =
      case Rooms.get_room(room_code) do
        {:ok, room_state} -> Map.get(room_state, :game_started, false)
        {:error, _} -> false
      end

    {:reply, %{game_started: game_started}, socket}
  end

  def handle_info({:room_public_changed, _room_code, _public}, socket) do
    {:noreply, assign(socket, :public_rooms, Rooms.list_public_rooms())}
  end
end
