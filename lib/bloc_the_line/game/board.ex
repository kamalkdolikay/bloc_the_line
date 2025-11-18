defmodule Board do
  @moduledoc """
  Defines and handles the game board.

  - `width`: Width of the board
  - `height`: Height of the board
  - `player_count`: How many players currently playing the game
                    Only from 2 (inclusive) to 4 (inclusive).
  - `board_map`: A map from a coordinate to a player.
             Never access it directly, use the functions to handle it.
  - 'count_map': A map from player to count of pieces placed.
                Useful to check if it is the first attempt of a player or not.

  Implementation of board is done with just a map of coordinates that have
  a player. If a coordinate is not found in the map, it means that there is no
  player in that part.

  All input functions accept only pieces as input, no direct coordinates.
  """

  defstruct [:width, :height, :player_count, :board_map, :count_map]

  @type coordinate :: {integer(), integer()}
  @type player :: :p1 | :p2 | :p3 | :p4
  @type board_map :: %{coordinate() => player()}
  @type count_map :: %{player() => integer()}
  @type validation_error ::
    :out_of_bounds
    | :overlap
    | :first_attempt_corner
    | :adjacent_edge
    | :no_corner_connected
  @type validation_result :: :ok | {:error, validation_error()}

  @type t :: %__MODULE__ {
    width: integer(),
    height: integer(),
    player_count: 2..4,
    board_map: board_map(),
    count_map: count_map()
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
      board_map: Map.new(),
      count_map: Map.new(),
    }
  end

  @doc """
  Checks the piece can be placed on the selected coordinate.

  If it is player's first attempt, check the placement of a piece is within the board,
  does not overlap with other placed pieces, and is placed at the corner.

  If it is not the player's first attempt, check the placement of a piece is within the board,
  does not overlap with other placed pieces, does not touch same player's edge, and is connected at least one corner of same player piece.
  """
  @spec can_place?(Board.t(), Piece.t(), coordinate(), player()) :: validation_result()
  def can_place?(board, piece, coord, player) do
    moved_piece = Piece.transform(piece, &coord_add(&1, coord))
    first_attempt? = Map.get(board.count_map, player, 0) == 0

    if first_attempt? do
      with :ok <- within_board(board, moved_piece),
          :ok <- no_overlap(board, moved_piece),
          :ok <- corner_placement(board, moved_piece) do
        :ok
      end
    else
      with :ok <- within_board(board, moved_piece),
          :ok <- no_overlap(board, moved_piece),
          :ok <- no_adjacent_edge(board, moved_piece, player),
          :ok <- corner_connected(board, moved_piece, player) do
        :ok
      end
    end
  end

  @doc"""
  Adds piece to board.

  First checks if the placement is valid. If valid, update Board(Add cells of piece to board_map and increase placement count of player in count_map)
  """
  @spec add_piece(Board.t(), Piece.t(), coordinate(), player()) :: Board.t()
  def add_piece(board, piece, coord, player) do
    case can_place?(board, piece, coord, player) do
      :ok ->
      moved_piece = Piece.transform(piece, &coord_add(&1, coord))
      {:ok, %Board{
        board
        | board_map: Enum.reduce(moved_piece.cells, board.board_map,
            &Map.put(&2, &1, player)),
            # Simplified version:
            # fn piece_part, acc_board_map ->
            #   Map.put(acc_board_map, piece_part, player)
            # end
          count_map: Map.put(board.count_map, player, Map.get(board.count_map, player, 0) + 1)
      }}
    {:error, _reason} ->
      # IO.inspect(reason) # For debugging
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
  @spec board_corners(Board.t()) :: list(coordinate())
  defp board_corners(%Board{} = board) do
    [{0, 0}, {0, board.height - 1}, {board.width - 1, 0}, {board.width - 1, board.height - 1}]
  end

  @spec within_board(Board.t(), Piece.t()) :: validation_result()
  defp within_board(%Board{width: width, height: height}, %Piece{cells: cells}) do
    if Enum.all?(cells, fn {x,y} ->
      0 <= x    and
      x < width and
      0 <= y    and
      y < height
    end) do
      :ok
    else
      {:error, :out_of_bounds}
    end
  end

  @spec no_overlap(Board.t(), Piece.t()) :: validation_result()
  defp no_overlap(%Board{board_map: board_map}, %Piece{cells: cells}) do
    Enum.reduce_while(cells, :ok, fn coord, _acc ->
      if Map.has_key?(board_map, coord) do
        {:halt, {:error, :overlap}}
      else
        {:cont, :ok}
      end
    end)
  end

  @spec corner_placement(Board.t(), Piece.t()) :: validation_result()
  defp corner_placement(%Board{} = board, %Piece{corners: corners}) do
    board_corners = board_corners(board)
    Enum.reduce_while(corners, {:error, :first_attempt_corner}, fn coord, _acc ->
      if coord in board_corners do
        {:halt, :ok}
      else
        {:cont, {:error, :first_attempt_corner}}
      end
    end)
  end

  @spec no_adjacent_edge(Board.t(), Piece.t(), player()) :: validation_result()
  defp no_adjacent_edge(%Board{board_map: board_map}, %Piece{corners: corners}, player) do
    Enum.reduce_while(corners, :ok, fn corner, _acc ->
      adjacent_coords = adjacent(corner)

      has_bad_neighbor =
        Enum.any?(adjacent_coords, fn adjacent_coord ->
          case Map.get(board_map, adjacent_coord) do
            ^player -> true
            _ -> false
          end
        end)

        if has_bad_neighbor do
          {:halt, {:error, :adjacent_edge}}
        else
          {:cont, :ok}
        end
    end)
  end

  @spec corner_connected(Board.t(), Piece.t(), player()) :: validation_result()
  defp corner_connected(%Board{board_map: board_map}, %Piece{corners: corners}, player) do
    Enum.reduce_while(corners, {:error, :no_corner_connected}, fn corner, _acc ->
    diagonal_coords = diagonal(corner)

    has_same_player_diagonal =
      Enum.any?(diagonal_coords, fn diagonal_coord ->
        case Map.get(board_map, diagonal_coord) do
          ^player -> true
          _ -> false
        end
      end)

      if has_same_player_diagonal do
          {:halt, :ok}
      else
          {:cont, {:error, :no_corner_connected}}
      end
    end)
  end
end
