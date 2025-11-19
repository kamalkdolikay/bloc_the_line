defmodule BlocTheLineWeb.Navbar do
  use Phoenix.Component

  def navbar(assigns) do
    ~H"""
    <div id="navbar" class="flex justify-between items-center">
      <div><img src="/images/bloc_the_line_logo.png" alt="Logo" class="h-12 w-auto" /></div>
      <.link navigate="" class="">Lobby</.link>
    </div>
    """
  end
end
