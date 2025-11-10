defmodule Piece do
  alias Piece # avoids having to use bloc_the_line.game.Piece
  defstruct name: nil, cells: [], corners: []

  @type coordinate :: {integer(), integer()}
  @type t :: %__MODULE__{name: String.t(), cells: MapSet.t(coordinate()), corners: MapSet.t(coordinate())}

end

defmodule Pieces do
  @pieces %{

    # F
    "F" => %Piece{},

    # I pieces
    "1" => %Piece{},
    "2" => %Piece{},
    "I3" => %Piece{},
    "I4" => %Piece{},
    "I5" => %Piece{},

    # L pieces
    "L4" => %Piece{},
    "L5" => %Piece{},

    # N
    "N" => %Piece{},

    # O
    "O" => %Piece{},

    # P
    "P" => %Piece{},

    # T
    "T4" => %Piece{},
    "T5" => %Piece{},

    # U
    "U" => %Piece{},

    # V
    "V3" => %Piece{},
    "V5" => %Piece{},

    # W
    "W" => %Piece{},

    # X
    "X" => %Piece{},

    # Y
    "X" => %Piece{},

    # Z
    "Z4" => %Piece{},
    "Z5" => %Piece{},
  }
end
