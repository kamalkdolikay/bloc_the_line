defmodule BlocTheLine.BoardTest do
  @moduledoc """
  Defines test cases for add_piece method.

  You can run only test script with this command:
  mix test test/bloc_the_line/board_test.exs
  """
  use ExUnit.Case, async: true
  @player :p1

  describe "add_piece/4 test" do
    setup do
      board = Board.new(10, 10, 1)
      piece = Pieces.get(:L4)

      # "L4" shape for reference:
      # █
      # █X█
      # cells:   [{0, 0}, {0, 1}, {1, 1}, {2, 1}]
      # corners: [{0, 0}, {0, 1}, {2, 1}]
      # anchor:  {1, 1}
      {:ok, %{board: board, piece: piece}}
    end

    test "1. fails when piece goes out of board", %{board: board, piece: piece} do
      assert {:err,
              %Board{width: 10, board_map: %{}, height: 10, player_count: 1, count_map: %{}}} =
               Board.add_piece(board, piece, {9, 9}, @player)
    end

    test "2. fails when pieces overlap",
         %{board: board, piece: piece} do
      # Success
      assert {:ok, board1} = Board.add_piece(board, piece, {0, 0}, @player)

      # Overlap
      assert {:err, _board1} = Board.add_piece(board1, piece, {0, 0}, @player)
    end

    test "3. succeeds when the piece is placed at the corner on first attempt", %{
      board: board,
      piece: piece
    } do
      # Success
      assert {:ok, board1} = Board.add_piece(board, piece, {0, 0}, @player)

      # Success
      assert Map.get(board1.board_map, {0, 0}) == @player
    end

    test "4. fails when the piece is not placed at the corner at first attempt", %{
      board: board,
      piece: piece
    } do
      assert {:err,
              %Board{width: 10, board_map: %{}, height: 10, player_count: 1, count_map: %{}}} =
               Board.add_piece(board, piece, {1, 1}, @player)
    end

    test "5. fails when edge of the piece touch the edges of same player's piece",
         %{board: board, piece: piece} do
      assert {:ok, _board1} = Board.add_piece(board, piece, {0, 0}, @player)

      assert {:err, _board1} = Board.add_piece(board, piece, {1, 2}, @player)
    end

    test "6. fails when corner of the piece is not connected to the corner of same player's piece ",
         %{board: board, piece: piece} do
      assert {:ok, board1} = Board.add_piece(board, piece, {0, 0}, @player)

      assert {:err, _board1} = Board.add_piece(board1, piece, {5, 5}, @player)
    end

    test "7. succeeds when corner of the piece is connected to the corner of same player's piece",
         %{board: board, piece: piece} do
      assert {:ok, board1} = Board.add_piece(board, piece, {0, 0}, @player)
      assert {:ok, board2} = Board.add_piece(board1, piece, {3, 2}, @player)

      assert Map.get(board2.board_map, {3, 2}) == @player
    end

    test "8. tests Z5 piece", %{board: board} do
      # █
      # █X█
      #   █
      # █  █
      # █X██X█
      #   █  █    This should not allowed.
      z5 = Pieces.get(:Z5)
      assert {:ok, board1} = Board.add_piece(board, z5, {0, 0}, @player)
      assert {:ok, board2} = Board.add_piece(board1, z5, {3, 3}, @player)

      assert {:err, _} =
               Board.add_piece(board2, z5, {0, 3}, @player)
    end

    test "9. tests P and L4", %{board: board} do
      #    █
      # █X█X
      # ██ ██ This should not allowed.
      p = Pieces.get(:P)
      l4 = Pieces.get(:L4)

      newP = p |> Piece.flip(:vertical) |> Piece.rotate(:ccw)
      newL4 = l4 |> Piece.rotate(:ccw) |> Piece.flip(:vertical)

      assert {:ok, board1} = Board.add_piece(board, newL4, {8, 7}, @player)
      assert {:err, _} = Board.add_piece(board, newP, {5, 8}, @player)
    end
  end
end
