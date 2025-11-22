defmodule Player do
  @moduledoc """
  Player state.
  - Board ownership lives in Board (do not store cell ownership here).
  - Coordinates: {x, y}, 0-based, top-left origin.
  """

  alias Piece

  @type coord :: {integer(), integer()}

  @type t :: %__MODULE__{
          id: binary(),     # 8 bytes uuid, should be randomly created for security (use :crypto)
          name: String.t(),
          color: non_neg_integer(), # More like a team or player number, not exactly colour
          points: non_neg_integer(),
          start_location: coord(),
          board_location: coord(),
          current_piece: Piece.t() | nil,
          ready: boolean(),
          joined_at: DateTime.t()
        }

  defstruct [
    :id,
    :name,
    :color,
    :start_location,
    :board_location,
    :joined_at,
    points: 0,
    current_piece: nil,
    ready: false
  ]

  # TODO: start changing stuff in player.ex
  @doc "Create a player; board_location starts at start_location."
  @spec new(String.t(), coord()) :: t()
  def new(name, {x, y} = start_location)
      when is_binary(name) and is_integer(x) and is_integer(y) do
    %Player{
      name: name,
      start_location: start_location,
      board_location: start_location
    }
  end

  @doc "Update avatar location on board."
  @spec update_board_location(t(), coord()) :: t()
  def update_board_location(%Player{} = player, {x, y})
      when is_integer(x) and is_integer(y) do
    %Player{player | board_location: {x, y}}
  end

  @doc "Set current piece (use nil to clear)."
  @spec set_current_piece(t(), Piece.t() | nil) :: t()
  def set_current_piece(%Player{} = player, piece) do
    %Player{player | current_piece: piece}
  end

  @doc "Clear current piece."
  @spec clear_current_piece(t()) :: t()
  def clear_current_piece(%Player{} = player) do
    %Player{player | current_piece: nil}
  end

  @doc "Add non-negative points."
  @spec add_points(t(), non_neg_integer()) :: t()
  def add_points(%Player{} = player, n)
      when is_integer(n) and n >= 0 do
    %Player{player | points: player.points + n}
  end

  @doc "Add points = piece cell count."
  @spec add_points_by_piece(t(), Piece.t()) :: t()
  def add_points_by_piece(%Player{} = player, %Piece{cells: cells}) do
    add_points(player, MapSet.size(cells))
  end

  @doc "Has placed first piece (points > 0)."
  @spec used_first_piece?(t()) :: boolean()
  def used_first_piece?(%Player{points: points}), do: points > 0

  @doc "Reset for new game; keep name/start_location."
  @spec reset_for_new_game(t()) :: t()
  def reset_for_new_game(%Player{} = player) do
    %Player{
      player
      | points: 0,
        board_location: player.start_location,
        current_piece: nil
    }
  end
end
