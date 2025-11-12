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

  @diag_coord [{1, 1}, {1, -1}, {-1, 1}, {-1, -1}]
  @adj_coord [{0, 1}, {0, -1}, {1, 1}, {-1, 0}]

  def new(width, height, player_count) do
    %Board{
      width,
      height,
      player_count,
      board_map: Map.new()
    }
  end

  def can_place?(%Board{} = board, %Piece{} = piece, coord, player) do
    moved_piece = Piece.transform(piece, &coord_add(&1, coord))
    # TODO
  end

  def add_piece(%Board{} = board, %Piece{} = piece, coord, player) do
    if can_place?(board, piece, coord, player) do
      moved_piece = Piece.transform(piece, &coord_add(&1, coord))
      {:ok, %Board{
        board
        | board_map: Enum.reduce(moved_piece.cells, board.board_map,
            &Map.put(&2, &1, player)
            # Simplified version:
            # fn piece_part, acc_board_map ->
            #   Map.put(acc_board_map, piece_part, player)
            # end
          )
      }}
    else
      {:err, board}
    end
  end

  def get_player_from_coord(%Board{} = board, coord) do
    Map.fetch(board.board_map, coord)
  end

  # PRIVATE HELPER FUNCTIONS

  defp check_coord(%Board{} = board, coord, player) do
    # not Map.has_key?(board.board_map, coord)
  end

  defp coord_add({x1, y1}, {x2, y2}) do {x1 + x2, y1 + y2} end

  defp adjacent({x, y} = coord) do
    Enum.map(@adj_coord, &coord_add(&1, coord))
  end

  defp diagonal({x, y} = coord) do
    Enum.map(@diag_coord, &coord_add(&1, coord))
  end

  defp corners(%Board{} = board) do
    [{0, 0}, {0, board.height}, {board.width, 0}, {board.width, board.height}]
  end

end
