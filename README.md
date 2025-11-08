# Bloc The Line
**Real-Time Multiplayer Blokus Game in Phoenix LiveView**

A zero JavaScript, full-stack real-time multiplayer Blokus experience built with Phoenix LiveView.  
Drag-and-drop polyominoes, strict official rules, GenServer powered game engine, PubSub sync, a smart matchmaking lobby.

---

### Features

- Zero JavaScript frontend (100% LiveView + HEEx)
- Real-time multiplayer (2–4 players)
- Official Blokus rules enforced (corner-touch, no edge adjacency, first-piece corner, etc.)
- Drag-and-drop piece placement
- Matchmaking lobby with shareable game IDs
- Auto-start when enough players join
- Responsive board & piece components

### Project Structure

```text
lib/
├── mix/
│   └── tasks/
│       └── phx.gen.live.module.ex   ← custom generator to build modules in live folder
│
├── bloc_the_line/                   ← Backend Logic (pure Elixir)
│   ├── guests/                      ← Multiplayer connections
│   │   └── users.ex
│   │           
│   ├── game/                        ← Core game logic
│   │   ├── game.ex                  ← Struct: %{board: [...], players: [...], turn: pid}
│   │   ├── game_server.ex           ← GenServer: place_piece/3, validate_move/3, end_game/1
│   │   ├── piece.ex                 ← Polyomino shapes/rotations
│   │   └── rules.ex                 ← is_valid?/3 (corner/edge checks)
│   │
│   └── lobby/                       ← Matchmaking
│       └── lobby.ex                 ← create_game/2, join_game/2
│
└── bloc_the_line_web/               ← Web App (LiveView + Components)
    ├── components/                  ← Reusable: <.board />, <.piece_drag />
    │   ├── layouts                  ← header, navbar, footer
    │   └── blokus_board.ex          ← board component
    │
    ├── layouts/                     ← root.html.heex, app.html.heex
    │
    ├── live/                        ← Features (Frontend)
    │   └── game/                    ← Subscribes to PubSub, renders board
    │       ├── game_live.ex         ← logic, state, events, data
    │       └── game_live.heex       ← html dynamic
    │
    ├── router.ex                    ← live "/game", GameLive, :index
    ├── endpoint.ex
    └── my_live_app_web.ex           ← import custom components in live_view function
```

### File Naming Conventions (Strict!)

| Type               | Pattern                     | Example                     | Notes                              |
|--------------------|-----------------------------|-----------------------------|------------------------------------|
| LiveView module    | `name_live.ex`              | `game_live.ex`              | Always ends with `_live.ex`        |
| LiveView template  | `name_live.html.heex`       | `game_live.html.heex`       | **Never** just `.heex`             |
| Function component | `component_name.heex` `component_name.ex`      | `components/board.heex` `components/board.ex`    | No `.html` suffix                  |
| **Forbidden**      | `*.heex` (standalone)       | `index_live.heex`           | Legacy pattern — do not use        |


> **Only exception:** Pure function components inside components/ → card.heex, piece_drag.heex, etc.



Following these rules keeps the codebase clean and avoids confusion between templates and modern HEEx function components.

### Custom Generator
**mix phx.gen.live.module**

> Phoenix's default generators scatter files. This custom task puts them exactly where they belong in a feature-foldered project. 
> This **custom generator** fixes it for **feature-foldered projects**.

#### Usage

```bash
mix phx.gen.live.module <Feature> <Name>
```

It generates LiveView modules and templates in the correct feature-scoped directories — exactly where you want them.

**Important**: Feature names are **case-sensitive** — always use `PascalCase`.

#### Location

```text
lib/mix/tasks/phx.gen.live.module.ex
```

### Examples

**1. Generate a "Home" live page**

```bash
command: mix phx.gen.live.module Home Home

output:
#→ creates:
lib/bloc_the_line_web/live/home/index_live.ex
lib/bloc_the_line_web/live/home/index_live.heex

To view it, add this line to your router.ex inside your scope:
live "/home", HomeLive, :index

# Case-sensitive — always use PascalCase
```

---





### How to Run This Project


#### Step 1: Clone this repo

```bash
https://github.com/kamalkdolikay/bloc_the_line.git
cd bloc_the_line
```

#### Run from terminal

```bash
mix deps.get
mix phx.server
```

### How to Play (not implemented)

1. Go to `/lobby`  
2. Click **New Game**  
3. Share the game ID  
4. Up to 4 players join → game starts automatically 

### Contributing

TBA

### License

MIT License © 2025 Bloc The Line

---

**Built with love using Phoenix LiveView — because JavaScript is optional.** 
Let the blocks fall where they may.