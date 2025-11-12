defmodule Board do
  @moduledoc """
  Defines and handles the game board.

  - `width`: Width of the board
  - `height`: Height of the board
  - `player_count`: How many players currently playing the game
                    Only from 2 (inclusive) to 4 (inclusive).
  - `board_map`: A map from a coordinate to a player.
             Never access it directly, use the functions to handle it.

  Implementation of board is done with just a map of coordinates that have
  a player. If a coordinate is not found in the map, it means that there is no
  player in that part.

  All input functions accept only pieces as input, no direct coordinates.
  """

  defstruct [:width, :height, :player_count, :board_map]

  @type coordinate :: {integer(), integer()}
  @type board_entry :: :p1 | :p2 | :p3 | :p4
  @type board_map :: map(coordinate(), board_entry())

  @type t :: %__MODULE__ {
    width: integer(),
    height: integer(),
    player_count: 2..4,
    board_map: board_map()
  }

  def new(width, height, player_count) do
    %Board{
      width,
      height,
      player_count,
      board_map: Map.new()
    }
  end

  def can_place?(%Board{} = board, %Piece{} = piece, {x, y} = coord, player) do
    moved_piece = Piece.transform(piece, &coord_add(&1, coord))
    # TODO
  end

  def add_piece(%Board{} = board, %Piece{} = piece, {x, y} = coord, player) do
    if can_place?(board, piece, coord, player) do
      moved_piece = Piece.transform(piece, &coord_add(&1, coord))
      %Board{
        board
        | board_map: Enum.reduce(moved_piece.cells, board.board_map,
            &Map.put(&2, &1, player)
            # Simplified version:
            # fn piece_part, acc_board_map ->
            #   Map.put(acc_board_map, piece_part, player)
            # end
          )
      }
    else
      board
    end
  end

end
