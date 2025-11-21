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
    └── bloc_the_line_web.ex         ← import custom components in live_view function
```

### File Naming Conventions (Strict!)

| Type               | Pattern                                   | Example                                       | Notes                       |
| ------------------ | ----------------------------------------- | --------------------------------------------- | --------------------------- |
| LiveView module    | `name_live.ex`                            | `game_live.ex`                                | Always ends with `_live.ex` |
| LiveView template  | `name_live.html.heex`                     | `game_live.html.heex`                         | **Never** just `.heex`      |
| Function component | `component_name.heex` `component_name.ex` | `components/board.heex` `components/board.ex` | No `.html` suffix           |
| **Forbidden**      | `*.heex` (standalone)                     | `index_live.heex`                             | Legacy pattern, do not use |

> **Only exception:** Pure function components inside components/ or live/feature/components → card.heex, piece_drag.heex, etc.

Following these rules keeps the codebase clean and avoids confusion between templates and modern HEEx function components.

### Custom Generator

**mix phx.gen.live.module**

> Phoenix's default generators scatter files. This **custom generator** puts them exactly where they belong in a feature-foldered project.

#### Usage

```bash
mix phx.gen.live.module <Feature> <Name>
```

It generates LiveView modules and templates in the correct feature-scoped directories exactly where you want them.

**Important**: Feature names are **case-sensitive**, always use `PascalCase`.

#### Location

```text
lib/mix/tasks/phx.gen.live.module.ex (custom generator)
```

### Examples

**1. Generate a "Home" live page**

```bash
command: mix phx.gen.live.module Home Home

output:
#→ creates:
lib/bloc_the_line_web/live/home/home_live.ex
lib/bloc_the_line_web/live/home/home_live.heex

To view it, add this line to your router.ex inside your scope:
live "/home", HomeLive, :index

# Case-sensitive, always use PascalCase
```

---

### How to Run This Project

#### 1. Clone this repo

```bash
https://github.com/kamalkdolikay/bloc_the_line.git
cd bloc_the_line
```

#### 2. Important for Windows users (line endings)
The project uses LF line endings for all Elixir files and enforces it with `.gitattributes`.
To avoid `mix format --check-formatted` failures and CRLF/LF mismatches on Windows, run once:
```bash
git config --global core.autocrlf false
```
This ensures Git does not automatically convert line endings on Windows, keeping everything consistent across Linux, macOS, and Windows.

> The included `.gitattributes` already marks all `*.ex`, `*.exs`, `*.heex`, etc. as `text eol=lf`, so with the above setting the formatter will behave identically on every OS.

#### 3. Install dependencies & start the server

```bash
mix deps.get
mix phx.server
```

### Formatting
```bash
# Format all files according to .formatter.exs (elixir files only)
mix format

# Optional: check if any files still need formatting (CI will fail if this returns non-zero)
mix format --check-formatted
```

Running `mix format` before you commit guarantees:  
   - No whitespace / line-ending conflicts  
   - Consistent code style across all contributors 
   - CI passes automatically

### How to Play (Lobby in progress!)

1. Go to `/`
2. Enter name
3. Click **Create Room**
4. Share the game ID
5. Up to 4 players join can join one room 
6. Game starts automatically

### Contributing

We love blocks and contributors!

> **Current status: Active development on `dev` branch**

#### Rules for merging into main:

1. All new work happens on the `dev` branch  
2. `dev` may contain non-critical bugs during active development  
3. **Never push directly to `main`**  
4. To release a stable version:  
   - Create a Pull Request from `dev` → `main`  
   - Ensure the game is **fully playable** with **no game-breaking bugs**  
   - At least **one other contributor** must review and approve  
   - Run full local multiplayer test (2–4 players)  
   - **Only then** merge into `main`

```bash
git checkout dev
git pull origin dev
git checkout -b feature/your-epic-idea

# .... code .....

# ALWAYS RUN BEFORE COMMITTING
mix format                     # formats elixir files
mix format --check-formatted   # should exit with code 0

git add .
git commit -m "Add epic idea"
git push origin feature/your-epic-idea

# Open PR: feature/your-epic-idea → dev
# When dev is stable → create PR: dev → main
```
> **main** = production-ready, stable, publicly shareable

### License

MIT License © 2025 Bloc The Line

---

**Built with love using Phoenix LiveView because JavaScript is optional.**
Let the blocks fall where they may.
