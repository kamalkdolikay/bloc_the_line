defmodule Piece do
  @moduledoc """
  provides the definition of a piece.

  - `cells` - a MapSet of relative coordinates `{x, y}` of all parts of a block
  - `corners` - a MapSet of the potential corner candidates
  - `name` - string identifier for each piece

  all coordinates are relative to an anchor point at `{0, 0}`,
  which tries to be the bottom-right cell of the piece (with exceptions).

  ## Examples

  # rotate or flip a piece (or both)
  Piece.rotate(piece, :cw)
  Piece.flip(piece, :vertical)

  piece |> Piece.rotate(:ccw) |> Piece.flip(:horizontal)
  """

  defstruct name: nil, cells: [], corners: []
  @type coordinate :: {integer(), integer()}
  @type t :: %__MODULE__{
          name: String.t(),
          cells: MapSet.t(coordinate()),
          corners: MapSet.t(coordinate())
        }

  @doc """
  rotate a piece 90 degrees around the anchor point
  use :cw for clockwise or :ccw for counter-clockwise 
  """
  def rotate(%Piece{} = piece, :cw) do
    transform(piece, fn {x, y} -> {-y, x} end)
  end

  def rotate(%Piece{} = piece, :ccw) do
    transform(piece, fn {x, y} -> {y, -x} end)
  end

  @doc """
  flip piece across an axis (:horizontal or :vertical)
  """
  def flip(%Piece{} = piece, :horizontal) do
    transform(piece, fn {x, y} -> {-x, y} end)
  end

  def flip(%Piece{} = piece, :vertical) do
    transform(piece, fn {x, y} -> {x, -y} end)
  end

  # helper functions to avoid pipes everywhere
  # applies the chosen rotate/flip to every pair of coordinates
  # inside cells and corners
  defp transform(%Piece{} = piece, transform_fn) do
    %{
      piece
      | cells: transform_coords(piece.cells, transform_fn),
        corners: transform_coords(piece.corners, transform_fn)
    }
  end

  defp transform_coords(mapset, transform_fn) do
    mapset
    |> Enum.map(transform_fn)
    |> MapSet.new()
  end
end

defmodule Pieces do
  @moduledoc """
  defines all game pieces via their cells and potential corners.

  try to anchor all pieces to the bottom right corner.

  In each comment, X is the anchor point {0, 0}, it also represents a filled in cell.

  for the 1 tile block we don't mark the anchor point.

  ## Examples

  # get a piece or its information:

  piece = Pieces.get("L4")
  piece.cells 
  piece.corners
  """

  @pieces %{
    # F
    # ===
    #  █
    # ██X
    # █ 
    "F" => %Piece{
      name: "F",
      cells: MapSet.new([{-2, 0}, {-1, 0}, {-1, -1}, {-2, 1}, {0, 0}]),
      corners: MapSet.new([{-2, 0}, {-2, 1}, {-1, -1}, {0, 0}])
    },

    # I
    # ===
    # █
    "1" => %Piece{
      name: "1",
      cells: MapSet.new([{0, 0}]),
      corners: MapSet.new([{0, 0}])
    },
    # █X
    "2" => %Piece{
      name: "2",
      cells: MapSet.new([{-1, 0}, {0, 0}]),
      corners: MapSet.new([{-1, 0}, {0, 0}])
    },
    # ██X
    "I3" => %Piece{
      name: "I3",
      cells: MapSet.new([{-2, 0}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-2, 0}, {0, 0}])
    },
    # ███X
    "I4" => %Piece{
      name: "I4",
      cells: MapSet.new([{-3, 0}, {-2, 0}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-3, 0}, {0, 0}])
    },
    # ████X     
    "I5" => %Piece{
      name: "I5",
      cells: MapSet.new([{-4, 0}, {-3, 0}, {-2, 0}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-4, 0}, {0, 0}])
    },

    # L
    # ===
    # █
    # ██X
    "L4" => %Piece{
      name: "L4",
      cells: MapSet.new([{0, 0}, {-1, 0}, {-2, 0}, {-2, -1}]),
      corners: MapSet.new([{0, 0}, {-2, 0}, {-2, -1}])
    },
    # ███X
    # █
    "L5" => %Piece{
      name: "L5",
      cells: MapSet.new([{-3, -1}, {-3, 0}, {-2, 0}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-3, -1}, {-3, 0}, {0, 0}])
    },

    # N
    # ===
    # ███
    # █X
    "N" => %Piece{
      name: "N",
      cells: MapSet.new([{0, -1}, {1, -1}, {2, -1}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{0, -1}, {2, -1}, {-1, 0}, {0, 0}])
    },

    # O
    # ===
    # ██
    # █X
    "O" => %Piece{
      name: "O",
      cells: MapSet.new([{-1, -1}, {0, -1}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-1, -1}, {0, -1}, {-1, 0}, {0, 0}])
    },

    # P
    # ===
    # ██
    # █X
    # █
    "P" => %Piece{
      name: "P",
      cells: MapSet.new([{-1, 1}, {-1, 0}, {-1, -1}, {0, -1}, {0, 0}]),
      corners: MapSet.new([{-1, 1}, {-1, -1}, {0, -1}, {0, 0}])
    },

    # T
    # ===
    # █
    # ██X
    "T4" => %Piece{
      name: "T4",
      cells: MapSet.new([{-1, -1}, {-2, 0}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-1, -1}, {-2, 0}, {0, 0}])
    },
    # █
    # █
    # ██X
    "T5" => %Piece{
      name: "T5",
      cells: MapSet.new([{-1, -2}, {-1, -1}, {-2, 0}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-1, -2}, {-2, 0}, {0, 0}])
    },

    # U
    # ===
    # ███
    # █ X
    "U" => %Piece{
      name: "U",
      cells: MapSet.new([{-2, -1}, {-1, -1}, {0, -1}, {-2, 0}, {0, 0}]),
      corners: MapSet.new([{-2, -1}, {0, -1}, {-2, 0}, {0, 0}])
    },

    # V
    # ===
    # ██
    # X
    "V3" => %Piece{
      name: "V3",
      cells: MapSet.new([{-1, -1}, {0, -1}, {0, 0}]),
      corners: MapSet.new([{-1, -1}, {0, -1}, {-1, 0}])
    },
    # █
    # █
    # ██X
    "V5" => %Piece{
      name: "V5",
      cells: MapSet.new([{-2, -2}, {-2, -1}, {-2, 0}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-2, -2}, {-2, 0}, {0, 0}])
    },

    # W
    # ===
    # █
    # ██
    # █X
    "W" => %Piece{
      name: "W",
      cells: MapSet.new([{-2, -2}, {-2, -1}, {-1, -1}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-2, -2}, {-2, -1}, {-1, -1}, {-1, 0}, {0, 0}])
    },
    # X
    # ===
    # █
    # ███
    # X
    "X" => %Piece{
      name: "X",
      cells: MapSet.new([{0, -2}, {1, -1}, {0, -1}, {-1, -1}, {0, 0}]),
      corners: MapSet.new([{0, -2}, {1, -1}, {-1, -1}, {0, 0}])
    },

    # Y
    # ===
    # ████     
    # X     
    "Y" => %Piece{
      name: "Y",
      cells: MapSet.new([{2, -1}, {1, -1}, {0, -1}, {-1, -1}, {0, 0}]),
      corners: MapSet.new([{-1, -1}, {2, -1}, {0, 0}])
    },

    # Z
    # ===
    # █
    # ██
    # X
    "Z4" => %Piece{
      name: "Z4",
      cells: MapSet.new([{-1, -2}, {-1, -1}, {0, -1}, {0, 0}]),
      corners: MapSet.new([{-1, -2}, {-1, -1}, {0, -1}, {0, 0}])
    },
    # █
    # ███
    #  X
    "Z5" => %Piece{
      name: "Z5",
      cells: MapSet.new([{-2, -2}, {-2, -1}, {-1, -1}, {0, -1}, {0, 0}]),
      corners: MapSet.new([{-2, -2}, {-2, -1}, {0, -1}, {0, 0}])
    }
  }

  def all, do: @pieces
  def get(name), do: Map.get(@pieces, name)
end
