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
          corner: coord(),
          board_location: coord(),
          current_piece: Piece.t() | nil,
          ready: boolean(),
          joined_at: DateTime.t()
        }

  defstruct [
    :id,
    :name,
    :color,
    :corner,
    :board_location,
    :joined_at,
    points: 0,
    current_piece: nil,
    ready: false
  ]

  @doc "Create a player; board_location starts at corner."
  @spec new(String.t(), non_neg_integer(), coord(), DateTime.t()) :: Player.t()
  def new(name, color, {x, y} = corner_coord, joined_at)
      when is_binary(name) and is_integer(x) and is_integer(y) do
    %Player{
      id: :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false),
      name: name,
      color: color,
      corner: corner_coord,
      board_location: corner_coord,
      joined_at: joined_at
    }
  end

  @doc "Update avatar location on board."
  @spec update_board_location(t(), coord()) :: t()
  def update_board_location(%Player{} = player, {x, y})
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    %Player{player | board_location: {x, y}}
  end

  @doc "Rename user to a new name."
  @spec rename(t(), String.t()) :: t()
  def rename(%Player{} = player, new_name) do
    %Player{player | name: new_name}
  end

  @doc "Update starting corner location on board."
  @spec update_corner(t(), coord()) :: t()
  def update_corner(%Player{} = player, {x, y})
      when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    %Player{player | corner: {x, y}}
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

  @doc "Reset for new game; keep name/corner."
  @spec reset_for_new_game(t()) :: t()
  def reset_for_new_game(%Player{} = player) do
    %Player{
      player
      | points: 0,
        board_location: player.corner,
        current_piece: nil
    }
  end
end
