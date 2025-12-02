# Bloc The Line - Game Rules & How to Play

## Game Overview

**Bloc The Line** is a real-time multiplayer strategy game based on the classic Blokus board game. Players compete on a 20x20 grid, strategically placing polyomino pieces to maximize their score while blocking opponents.

---

## Game Objective

- Place as many pieces as possible on the board
- Block opponents from placing their pieces
- Achieve the highest score before time runs out
- Be the last player able to place pieces

---

## Basic Rules

### 1. Game Setup

- **Number of Players**: 2-4 players
- **Board Size**: 20x20 grid
- **Time Limit**: Each game has a countdown timer (default 60 seconds)
- **Piece Types**: 21 different polyomino shapes (ranging from 1 to 5 cells)

### 2. Starting Positions

Each player is assigned a **starting corner** at the beginning of the game:
- **P1 (Blue)**: Top-left corner (0, 0)
- **P2 (Red)**: Top-right corner (19, 0)
- **P3 (Green)**: Bottom-left corner (0, 19)
- **P4 (Purple)**: Bottom-right corner (19, 19)

### 3. First Piece Placement Rules

**Your first piece must:**
- Be placed within the board boundaries
- Not overlap with any already placed pieces
- **Must be placed at your assigned starting corner**
- At least **one corner** of your piece must exactly match your starting corner coordinates

### 4. Subsequent Placement Rules

**From your second piece onwards, each placement must satisfy:**
-  Within board boundaries
-  No overlap with any placed pieces
-  **Cannot be edge-to-edge adjacent with your own pieces** (cannot share an edge)
-  **Must have at least one corner diagonally connected to your existing pieces** (corner-to-corner contact)

**Key Concepts:**
- **Diagonal Connection**: A corner of your piece touches a corner of your existing piece diagonally (✓ Allowed)
- **Edge-to-Edge Adjacent**: Your piece shares an edge with your existing piece (✗ Not Allowed)

### 5. Interacting with Other Players' Pieces

- Your pieces **can** be edge-to-edge adjacent with other players' pieces
- Your pieces **can** overlap with other players' pieces (but the system will prevent this)
- You **cannot** block other players from placing their pieces (unless the board is full)

---

## How to Play

### Controls

The game uses keyboard controls:

| Key | Action |
|-----|--------|
| **W / ↑** | Move piece up |
| **A / ←** | Move piece left |
| **S / ↓** | Move piece down |
| **D / →** | Move piece right |
| **R** | Rotate piece clockwise |
| **E** | Rotate piece counter-clockwise |
| **F** | Flip piece horizontally |
| **V** | Flip piece vertically |
| **SPACE** | Place piece |

### Gameplay Flow

1. **Receive Piece**: The system randomly assigns a piece to you
2. **Move Piece**: Use WASD keys to move the piece to your desired position
3. **Rotate/Flip**: Use R/E/F/V keys to adjust the piece orientation
4. **Place Piece**: When the piece is in a valid position, press **SPACE** to place it
5. **Get New Piece**: After successful placement, the system assigns a new random piece

---

## Scoring System

- Each piece earns points based on its size
- Larger pieces earn more points
- At game end, the player with the highest score wins
- In case of a tie, all players with the highest score share the victory

---

## Game End Conditions

The game ends when:

1. **Time Runs Out**: The countdown timer reaches zero
2. **No Valid Moves**: No player can place any pieces
3. **Player Leaves**: A player exits the room

### Post-Game

- Final scores are calculated for all players
- Winners are displayed (or tie results)
- Players can choose to stay in the room or return to the lobby to create a new game

---

## Strategy Tips

### Opening Strategy
- Expand quickly from your corner
- Use larger pieces to claim more territory
- Save smaller pieces for filling gaps later

### Mid-Game Strategy
- Observe opponents' placement patterns
- Try to block opponents' expansion paths
- Reserve placement space for yourself

### End-Game Strategy
- Use smaller pieces to fill remaining spaces
- Ensure your piece network remains connected
- Avoid being completely surrounded by opponents

---

## Frequently Asked Questions

### Q: Why can't I place my piece?

**A:** Possible reasons:
1. **First Placement**: The piece is not at your starting corner
2. **Subsequent Placements**: The piece is not diagonally connected to your existing pieces
3. **Edge-to-Edge**: The piece shares an edge with your existing pieces (not allowed)
4. **Out of Bounds**: The piece extends beyond the board boundaries
5. **Overlap**: The piece overlaps with other pieces

### Q: How do I know where my starting corner is?

**A:** The game interface displays corner markers (P1, P2, P3, P4) for each player with corresponding colored borders.

### Q: Can I skip my turn?

**A:** No. If you cannot place your current piece, you must wait for the system to assign a new piece, or wait for the game to end.

### Q: Is there a time limit?

**A:** Yes, each game has a countdown timer. The timer turns red when time is running low to alert you.

---

## Technical Notes

- **Real-time Sync**: All player actions are synchronized in real-time to other players
- **Automatic Validation**: The system automatically validates each placement against the rules
- **Error Feedback**: If placement is invalid, the piece will shake to indicate an error, but won't be placed

---

## Getting Started

### Running the Game Locally

1. **Start the server**:
   ```bash
   mix phx.server
   ```

2. **Access the game**:
   - Open your web browser
   - Navigate to: **http://localhost:4000**
   - Or use: **http://127.0.0.1:4000**

3. **Play the game**:
   - Enter your name
   - Create a room or join an existing room
   - Wait for all players to be ready
   - Host clicks "Start Game"
   - Enjoy the game!

> **Note**: The server runs on port 4000 by default. You should see a message like:
> ```
> [info] Running BlocTheLineWeb.Endpoint with Bandit 1.8.0 at 127.0.0.1:4000 (http)
> [info] Access BlocTheLineWeb.Endpoint at http://localhost:4000
> ```

---

**Good luck and become the Bloc The Line champion!** 
