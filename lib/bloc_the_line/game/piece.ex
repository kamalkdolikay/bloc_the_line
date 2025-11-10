defmodule Piece do
  defstruct name: nil, cells: [], corners: []

  @type coordinate :: {integer(), integer()}
  @type t :: %__MODULE__{name: String.t(), cells: MapSet.t(coordinate()), corners: MapSet.t(coordinate())}
end
