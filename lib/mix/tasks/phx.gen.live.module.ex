defmodule Mix.Tasks.Phx.Gen.Live.Module do
  use Mix.Task
  import Mix.Generator

  @shortdoc "Generates a simple LiveView module and template (no Ecto, no schema)"

  @moduledoc """
  Generates a barebones LiveView module and template without Ecto or forms.

  ## Usage

      mix phx.gen.live.module Feature Name

  Example:

      mix phx.gen.live.module Game Game

  This will generate:

      * lib/my_app_web/live/game/game_live.ex
      * lib/my_app_web/live/game/game_live.html.heex

  And you'll need to manually add this route in router.ex:

      live "/game", GameLive, :index
  """

  @impl true
  def run([feature, name | _]) do
    app = Mix.Phoenix.otp_app()
    base = Mix.Phoenix.base()
    web_module = Module.concat(["#{base}Web"])
    live_module = Module.concat([web_module, "#{name}Live"])
    web_path = Mix.Phoenix.web_path(app)

    # Create directory like: lib/my_app_web/live/game/
    live_dir = Path.join([web_path, "live", Macro.underscore(feature)])
    create_directory(live_dir)

    live_path = Path.join(live_dir, "#{Macro.underscore(name)}_live.ex")
    template_path = Path.join(live_dir, "#{Macro.underscore(name)}_live.html.heex")

    create_file(live_path, live_template(live_module))
    create_file(template_path, heex_template())

    Mix.shell().info("""
    * Created LiveView files:
      - #{live_path}
      - #{template_path}

    👉 To view it, add this line to your router.ex inside your scope:

        live "/#{Macro.underscore(feature)}", #{name}Live, :index
    """)
  end

  def run(_args) do
    Mix.shell().error("Usage: mix phx.gen.live.module Feature Name")
  end

  defp live_template(module) do
    # Convert module atom to string and remove leading "Elixir." if present
    module_name = module |> to_string() |> String.trim_leading("Elixir.")

    # Get parent module path (e.g., MyLiveAppWeb)
    parent_parts =
      module
      |> Module.split()
      |> Enum.drop(-1)

    parent_module =
      case parent_parts do
        [] -> "Phoenix.LiveView"
        parts -> Enum.join(parts, ".")
      end

    # Remove "Elixir." from parent too
    parent_module = parent_module |> String.trim_leading("Elixir.")

    """
    defmodule #{module_name} do
      use #{parent_module}, :live_view

      @impl true
      def mount(_params, _session, socket) do
        {:ok, assign(socket, counter: 0)}
      end

      @impl true
      def handle_event("inc", _value, socket) do
        {:noreply, update(socket, :counter, &(&1 + 1))}
      end
    end
    """
  end

  defp heex_template do
    """
    <div class="p-8 text-center">
      <h1>Counter: <%= @counter %></h1>
      <button phx-click="inc" class="border rounded px-4 py-2 mt-4">Increment</button>
    </div>
    """
  end
end
