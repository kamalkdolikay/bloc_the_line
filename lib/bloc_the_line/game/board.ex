defmodule Board do
  @moduledoc """
  Defines and handles the game board.

  - `width`: Width of the board
  - `height`: Height of the board
  - `player_count`: How many players currently playing the game
                    Only from 2 (inclusive) to 4 (inclusive).
  - `board`: A map from a coordinate to a player.
             Never access it directly, use the functions to handle it.

  Implementation of board is done with just a map of coordinates that have
  a player. If a coordinate is not found in the map, it means that there is no
  player in that part.

  All input functions accept only pieces as input, no direct coordinates.
  """

  defstruct [:width, :height, :player_count, :board]

  @type coordinate :: {integer(), integer()}
  @type board_entry :: :p1 | :p2 | :p3 | :p4
  @type board :: map(coordinate(), board_entry())
  @type t :: %__MODULE__ {
    width: integer(),
    height: integer(),
    player_count: 2..4,
    board: board()
  }


end
