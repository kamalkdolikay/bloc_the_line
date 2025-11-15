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
  @type player() :: :p1 | :p2 | :p3 | :p4
  @type board_map :: %{coordinate() => player()}

  @type t :: %__MODULE__ {
    width: integer(),
    height: integer(),
    player_count: 2..4,
    board_map: board_map()
  }

  # List of referential points used to calculated points diagonal to a coordinate.
  # E.g. {x + 1, y + 1} is at the diagonal of {x, y}
  @diag_coord [{1, 1}, {1, -1}, {-1, 1}, {-1, -1}]

  # List of referential points used to calculated points adjacent to a coordinate.
  # E.g. {x + 0, y + 1} is adjacent of {x, y}
  @adj_coord [{0, 1}, {0, -1}, {1, 1}, {-1, 0}]

  @spec new(integer(), integer(), 2..4) :: Board.t()
  def new(width, height, player_count) do
    %Board{
      width: width,
      height: height,
      player_count: player_count,
      board_map: Map.new()
    }
  end

  @spec can_place?(Board.t(), Piece.t(), coordinate(), player()) :: boolean()
  def can_place?(_board, piece, coord, _player) do
    _moved_piece = Piece.transform(piece, &coord_add(&1, coord))
    # TODO
  end

  @spec add_piece(Board.t(), Piece.t(), coordinate(), player()) :: Board.t()
  def add_piece(board, piece, coord, player) do
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

  @doc """
  Gets the player info from the coordinate.
  Returns {:ok, player} if succeeds to find a place.
  Or returns :error, if not.
  """
  @spec get_player_from_coord(Board.t(), coordinate()) :: player()
  def get_player_from_coord(board, coord) do
    Map.fetch(board.board_map, coord)
  end

  # PRIVATE HELPER FUNCTIONS

  @spec coord_add(coordinate(), coordinate()) :: coordinate()
  defp coord_add({x1, y1}, {x2, y2}) do {x1 + x2, y1 + y2} end

  # Returns the coordinates adjacent to an origin coordinate.
  @spec adjacent(coordinate()) :: list(coordinate())
  defp adjacent({_, _} = coord) do
    Enum.map(@adj_coord, &coord_add(&1, coord))
  end

  # Returns the coordinates diagonal to an origin coordinate.
  @spec diagonal(coordinate()) :: list(coordinate())
  defp diagonal({_, _} = coord) do
    Enum.map(@diag_coord, &coord_add(&1, coord))
  end

  # Returns the coordinates of the 4 corners of a board.
  @spec corners(Board.t()) :: list(coordinate())
  defp corners(%Board{} = board) do
    [{0, 0}, {0, board.height}, {board.width, 0}, {board.width, board.height}]
  end

end
