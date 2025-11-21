defmodule Piece do
  @moduledoc """
  provides the definition of a piece.

  - `name` - string identifier for each piece
  - `cells` - a MapSet of relative coordinates `{x, y}` of all parts of a block
  - `corners` - a MapSet of the potential corner candidates
  - `anchor` - a MapSet representing the 'pivot point' of a piece

  all coordinates are relative to top left at `{0, 0}`,

  ## Examples

  # rotate or flip a piece (or both)
  Piece.rotate(piece, :cw)
  Piece.flip(piece, :vertical)

  piece |> Piece.rotate(:ccw) |> Piece.flip(:horizontal)
  """

  @piece_names [
    :F,
    :"1",
    :"2",
    :I3,
    :I4,
    :I5,
    :L4,
    :L5,
    :N,
    :O,
    :P,
    :T4,
    :T5,
    :U,
    :V3,
    :V5,
    :W,
    :X,
    :Y,
    :Z4,
    :Z5
  ]
  Enum.each(@piece_names, fn _ -> :ok end)

  defstruct name: nil, cells: [], corners: [], anchor: {0, 0}
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
    {ax, ay} = piece.anchor

    transform(piece, fn {x, y} ->
      # translate to origin coordinates
      rel_x = x - ax
      rel_y = y - ay
      # now rotate
      new_x = -rel_y
      new_y = rel_x
      # translate back
      {new_x + ax, new_y + ay}
    end)
  end

  def rotate(%Piece{} = piece, :ccw) do
    {ax, ay} = piece.anchor

    transform(piece, fn {x, y} ->
      # translate to origin coordinates
      rel_x = x - ax
      rel_y = y - ay
      # rotate
      new_x = rel_y
      new_y = -rel_x
      # translate back
      {new_x + ax, new_y + ay}
    end)
  end

  @doc """
  flip piece across an axis (:horizontal or :vertical)
  """
  def flip(%Piece{} = piece, :horizontal) do
    {ax, ay} = piece.anchor

    transform(piece, fn {x, y} ->
      rel_x = x - ax
      rel_y = y - ay
      # negate x to flip horizontally
      new_x = -rel_x
      new_y = rel_y
      {new_x + ax, new_y + ay}
    end)
  end

  def flip(%Piece{} = piece, :vertical) do
    {ax, ay} = piece.anchor

    transform(piece, fn {x, y} ->
      rel_x = x - ax
      rel_y = y - ay
      # negate y to flip vertically
      new_x = rel_x
      new_y = -rel_y
      {new_x + ax, new_y + ay}
    end)
  end

  # helper functions to avoid pipes everywhere
  # applies the chosen rotate/flip to every pair of coordinates
  # inside cells and corners
  def transform(%Piece{} = piece, transform_fn) do
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

  try to anchor all pieces in the center

  In each comment, X is the anchor point and it also represents a filled in cell.

  for the 1 tile block we don't mark the anchor point.

  ## Examples

  # get a piece or its information:

  piece = Pieces.get("L4")
  piece.cells
  piece.corners
  piece.anchor
  """

  @pieces %{
    # F
    # ===
    #  █
    # █X█
    # █
    :F => %Piece{
      name: "F",
      cells: MapSet.new([{1, 0}, {0, 1}, {1, 1}, {2, 1}, {0, 2}]),
      corners: MapSet.new([{1, 0}, {0, 1}, {2, 1}, {0, 2}]),
      anchor: {1, 1}
    },

    # I
    # ===
    # █
    :"1" => %Piece{
      name: "1",
      cells: MapSet.new([{0, 0}]),
      corners: MapSet.new([{0, 0}])
    },
    # X█
    :"2" => %Piece{
      name: "2",
      cells: MapSet.new([{0, 0}, {1, 0}]),
      corners: MapSet.new([{0, 0}, {1, 0}])
    },
    # █X█
    :I3 => %Piece{
      name: "I3",
      cells: MapSet.new([{0, 0}, {1, 0}, {2, 0}]),
      corners: MapSet.new([{0, 0}, {0, 2}]),
      anchor: {1, 0}
    },
    # █X██
    :I4 => %Piece{
      name: "I4",
      cells: MapSet.new([{0, 0}, {1, 0}, {2, 0}, {3, 0}]),
      corners: MapSet.new([{0, 0}, {3, 0}]),
      anchor: {1, 0}
    },
    # ██X██
    :I5 => %Piece{
      name: "I5",
      cells: MapSet.new([{0, 0}, {1, 0}, {2, 0}, {3, 0}, {4, 0}]),
      corners: MapSet.new([{0, 0}, {4, 0}]),
      anchor: {2, 0}
    },

    # L
    # ===
    # █
    # █X█
    :L4 => %Piece{
      name: "L4",
      cells: MapSet.new([{0, 0}, {0, 1}, {1, 1}, {2, 1}]),
      corners: MapSet.new([{0, 0}, {0, 1}, {2, 1}]),
      anchor: {1, 1}
    },
    # █X██
    # █
    :L5 => %Piece{
      name: "L5",
      cells: MapSet.new([{0, 0}, {1, 0}, {2, 0}, {3, 0}, {0, 1}]),
      corners: MapSet.new([{0, 0}, {3, 0}, {0, 1}]),
      anchor: {1, 0}
    },

    # N
    # ===
    #  X██
    # ██
    :N => %Piece{
      name: "N",
      cells: MapSet.new([{1, 0}, {2, 0}, {3, 0}, {0, 1}, {1, 1}]),
      corners: MapSet.new([{1, 0}, {3, 0}, {0, 1}, {1, 1}]),
      anchor: {1, 0}
    },

    # O
    # ===
    # X█
    # ██
    :O => %Piece{
      name: "O",
      cells: MapSet.new([{0, 0}, {1, 0}, {0, 1}, {1, 1}]),
      corners: MapSet.new([{0, 0}, {1, 0}, {0, 1}, {1, 1}])
    },

    # P
    # ===
    # ██
    # X█
    # █
    :P => %Piece{
      name: "P",
      cells: MapSet.new([{0, 0}, {1, 0}, {0, 1}, {1, 1}, {0, 2}]),
      corners: MapSet.new([{0, 0}, {1, 0}, {1, 1}, {0, 2}]),
      anchor: {0, 1}
    },

    # T
    # ===
    #  █
    # █X█
    :T4 => %Piece{
      name: "T4",
      cells: MapSet.new([{1, 0}, {0, 1}, {1, 1}, {2, 1}]),
      corners: MapSet.new([{1, 0}, {0, 1}, {2, 1}]),
      anchor: {1, 1}
    },
    #  █
    #  X
    # ███
    :T5 => %Piece{
      name: "T5",
      cells: MapSet.new([{1, 0}, {1, 1}, {2, 0}, {2, 1}, {2, 2}]),
      corners: MapSet.new([{1, 0}, {2, 0}, {2, 2}]),
      anchor: {1, 1}
    },

    # U
    # ===
    # █X█
    # █ █
    :U => %Piece{
      name: "U",
      cells: MapSet.new([{0, 0}, {1, 0}, {2, 0}, {0, 1}, {2, 1}]),
      corners: MapSet.new([{0, 0}, {2, 0}, {0, 1}, {2, 1}]),
      anchor: {1, 0}
    },

    # V
    # ===
    # █X
    #  █
    :V3 => %Piece{
      name: "V3",
      cells: MapSet.new([{0, 0}, {1, 0}, {1, 1}]),
      corners: MapSet.new([{0, 0}, {1, 0}, {1, 1}]),
      anchor: {1, 0}
    },
    # █
    # █
    # X██
    :V5 => %Piece{
      name: "V5",
      cells: MapSet.new([{0, 0}, {0, 1}, {0, 2}, {1, 2}, {2, 2}]),
      corners: MapSet.new([{0, 0}, {0, 2}, {2, 2}]),
      anchor: {0, 2}
    },

    # W
    # ===
    # █
    # █X
    #  ██
    :W => %Piece{
      name: "W",
      cells: MapSet.new([{0, 0}, {0, 1}, {1, 1}, {1, 2}, {2, 2}]),
      corners: MapSet.new([{0, 0}, {0, 1}, {1, 1}, {1, 2}, {2, 2}]),
      anchor: {1, 1}
    },
    # X
    # ===
    #  █
    # █X█
    #  █
    :X => %Piece{
      name: "X",
      cells: MapSet.new([{1, 0}, {0, 1}, {1, 1}, {2, 1}, {1, 2}]),
      corners: MapSet.new([{1, 0}, {0, 1}, {2, 1}, {1, 2}]),
      anchor: {1, 1}
    },

    # Y
    # ===
    # █X██
    #  █
    :Y => %Piece{
      name: "Y",
      cells: MapSet.new([{0, 0}, {1, 0}, {2, 0}, {3, 0}, {1, 1}]),
      corners: MapSet.new([{0, 0}, {3, 0}, {1, 1}])
    },

    # Z
    # ===
    # █
    # █X
    #  █
    :Z4 => %Piece{
      name: "Z4",
      cells: MapSet.new([{0, 0}, {0, 1}, {1, 1}, {1, 2}]),
      corners: MapSet.new([{0, 0}, {0, 1}, {1, 1}, {1, 2}]),
      anchor: {1, 1}
    },
    # █
    # █X█
    #   █
    :Z5 => %Piece{
      name: "Z5",
      cells: MapSet.new([{0, 0}, {0, 1}, {1, 1}, {2, 1}, {2, 2}]),
      corners: MapSet.new([{0, 0}, {0, 1}, {2, 1}, {2, 2}]),
      anchor: {1, 1}
    }
  }

  @ordered_piece_names [
    "F",
    "1",
    "2",
    "I3",
    "I4",
    "I5",
    "L4",
    "L5",
    "N",
    "O",
    "P",
    "T4",
    "T5",
    "U",
    "V3",
    "V5",
    "W",
    "X",
    "Y",
    "Z4",
    "Z5"
  ]

  @x_piece_name "X"

  @doc """
  Returns the names of all pieces in order, including the X piece.

  Used when rotating through the full set of pieces (including X piece).
  """
  def piece_names do
    @ordered_piece_names
  end

  @doc """
  Returns the names of pieces that should be available at the start of the game.

  This excludes the X piece so that it cannot be selected at the start.
  """
  def starting_piece_names do
    Enum.reject(@ordered_piece_names, &(&1 == @x_piece_name))
  end

  @doc """
  Returns all pieces in rotation order as %Piece{} structs (including X piece).
  """
  def piece_list do
    @ordered_piece_names
    |> Enum.map(&get/1)
  end

  @doc """
  Returns the starting set of pieces as %Piece{} structs, excluding the X piece.
  """
  def starting_pieces do
    starting_piece_names()
    |> Enum.map(&get/1)
  end

  @doc """
  Given a current piece name, returns the next piece name in the rotation list.

  Wraps around to the first piece when called on the last one.
  If the current name is not found, it defaults to the first piece.
  """
  def next_piece_name(current_name) do
    case Enum.find_index(@ordered_piece_names, &(&1 == current_name)) do
      nil ->
        hd(@ordered_piece_names)

      idx ->
        next_index = rem(idx + 1, length(@ordered_piece_names))
        Enum.at(@ordered_piece_names, next_index)
    end
  end

  def all, do: @pieces
  def get(name), do: Map.get(@pieces, name)
end
