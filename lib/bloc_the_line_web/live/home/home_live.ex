defmodule BlocTheLineWeb.HomeLive do
  use BlocTheLineWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, counter: 0)}
  end

  @impl true
  def handle_event("inc", _value, socket) do
    {:noreply, update(socket, :counter, &(&1 + 1))}
  end
end
