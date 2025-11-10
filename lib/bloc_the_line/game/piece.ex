defmodule Piece do
  alias Piece # avoids having to use bloc_the_line.game.Piece

  # name is a bit redundant but included since it will show in IO.inspect()
  defstruct name: nil, cells: [], corners: []
  @type coordinate :: {integer(), integer()}
  @type t :: %__MODULE__{name: String.t(), cells: MapSet.t(coordinate()), corners: MapSet.t(coordinate())}

end

defmodule Pieces do
  # try to anchor all pieces to the bottom right corner

  # X is the anchor point, it also represents a filled in cell
  # for the 1 tile block we don't mark X 

  @pieces %{

    # F
    #===
    # █
    #██X
    #█ 
    "F" => %Piece{
      name: "F",
      cells: MapSet.new([{0, -2}, {0, -1}, {-1, -1}, {-2, 1}, {0, 0}]),
      corners: MapSet.new([{1, -2}, {2, -1}, {0, 0}])
    },

    # I
    #===
    #█
    "1" => %Piece{
      name: "1",
      cells: MapSet.new([{0, 0}]),
      corners: MapSet.new([{0, 0}])
    },
    #█X
    "2" => %Piece{
      name: "2",
      cells: MapSet.new([{-1, 0}, {0, 0}]),
      corners: MapSet.new([{-1, 0}, {0, 0}])
    },
    #██X
    "I3" => %Piece{
      name: "I3",
      cells: MapSet.new([{-2, 0}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-2, 0}, {0, 0}])
    },
    #███X
    "I4" => %Piece{
      name: "I4",
      cells: MapSet.new([{-3, 0}, {-2, 0}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-3, 0}, {0, 0}])
    },
    #████X     
    "I5" => %Piece{
      name: "I5",
      cells: MapSet.new([{-4, 0}, {-3, 0}, {-2, 0}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-4, 0}, {0, 0}])
    },

    # L
    #===
    #█
    #██X
    "L4" => %Piece{
      name: "L4",
      cells: MapSet.new([{0, 0}, {-1, 0}, {-2, 0}, {-2, -1}]),
      corners: MapSet.new([{0, 0}, {-2, 0}, {-2, -1}])
    },
    #███X
    #█
    "L5" => %Piece{
      name: "L5",
      cells: MapSet.new([{-3, -1}, {-3, 0}, {-2, 0}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-3, -1}, {-3, 0}, {0, 0}])
    },

    # N
    #===
    # ███
    #█X
    "N" => %Piece{
      name: "N",
      cells: MapSet.new([{0, -1}, {1, -1}, {2, -1}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{0, -1}, {2, -1}, {-1, 0}, {0, 0}]),
    },

    # O
    #===
    #██
    #█X
    "O" => %Piece{
      name: "O",
      cells: MapSet.new([{-1, -1}, {0, -1}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-1, -1}, {0, -1}, {-1, 0}, {0, 0}])
    },

    # P
    #===
    #██
    #█X
    #█
    "P" => %Piece{
      name: "P",
      cells: MapSet.new([{-1, 1}, {-1, 0}, {-1, -1}, {0, -1}, {0, 0}]),
      corners: MapSet.new([{-1, 1}, {-1, -1}, {0, -1}, {0, 0}]), 
    },

    # T
    #===
    # █
    #██X
    "T4" => %Piece{
      name: "T4",
      cells: MapSet.new([{-1, -1}, {-2, 0}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-1, -1}, {-2, 0}, {0, 0}])
    },
    # █
    # █
    #██X
    "T5" => %Piece{
      name: "T5",
      cells: MapSet.new([{-1, -2}, {-1, -1}, {-2, 0}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-1, -2}, {-2, 0}, {0, 0}])
    },

    # U
    #===
    #███
    #█ X
    "U" => %Piece{
      name: "U",
      cells: MapSet.new([{-2, -1}, {-1, -1}, {0, -1}, {-2, 0}, {0, 0}]),
      corners: MapSet.new([{-2, -1}, {0, -1}, {-2, 0}, {0, 0}])
    },

    # V
    #===
    #██
    # X
    "V3" => %Piece{
      name: "V3",
      cells: MapSet.new([{-1, -1}, {0, -1}, {0, 0}]),
      corners: MapSet.new([{-1, -1}, {0, -1}, {-1, 0}])
    },
    #█
    #█
    #██X
    "V5" => %Piece{
      name: "V5",
      cells: MapSet.new([{-2, -2}, {-2, -1}, {-2, 0}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-2, -2}, {-2, 0}, {0, 0}])
    },

    # W
    #===
    #█
    #██
    # █X
    "W" => %Piece{
      name: "W",
      cells: MapSet.new([{-2, -2}, {-2, -1}, {-1, -1}, {-1, 0}, {0, 0}]),
      corners: MapSet.new([{-2, -2}, {-2, -1}, {-1, -1}, {-1, 0}, {0, 0}])
    },
    # X
    #===
    # █
    #███
    # X
    "X" => %Piece{
      cells: MapSet.new([{0, -2}, {1, -1},{0, -1},{-1, -1}, {0, 0}]),
      corners: MapSet.new([{0, -2}, {1, -1},{-1, -1}, {0, 0}]), 
    },

    # Y
    #===
    #████     
    # X     
    "Y" => %Piece{
      cells: MapSet.new([{2, -1}, {1, -1},{0, -1},{-1, -1}, {0, 0}]),
      corners: MapSet.new([{-1, -1}, {2, -1}, {0, 0}]),
    },

    # Z
    #===
    #█
    #██
    # X
    "Z4" => %Piece{
      name: "Z4",
      cells: MapSet.new([{-1, -2}, {-1, -1}, {0, -1}, {0, 0}]),
      corners: MapSet.new([{-1, -2}, {-1, -1}, {0, -1}, {0, 0}]),
    },
    #█
    #███
    #  X
    "Z5" => %Piece{
      name: "Z5",
      cells: MapSet.new([{-2, -2}, {-2, -1}, {-1, -1}, {0, -1}, {0, 0}]),
      corners: MapSet.new([{-2, -2}, {-2, -1}, {0, -1}, {0, 0}]),
    }
  }
end
