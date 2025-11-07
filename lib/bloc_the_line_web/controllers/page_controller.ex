defmodule BlocTheLineWeb.PageController do
  use BlocTheLineWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
