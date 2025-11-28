defmodule GameTimer do
  @moduledoc """
  Utility module for managing the game timer.

  provides functions to start, reset, and cancel a timer that sends :game_over_timeout
  to the calling GenServer when it expires.
  """

  # default game timer
  @default_timer_duration_seconds 5

  @doc """
  Starts a new game over timer.

  Returns a timer reference that should be stored in game state.
  """
  def start_timer(duration_seconds \\ @default_timer_duration_seconds) do
    Process.send_after(self(), :game_over_timeout, duration_seconds * 1000)
  end

  @doc """
  Cancels an existing timer.

  Pass the timer reference from game state.
  """
  def cancel_timer(timer_ref) when is_reference(timer_ref) do
    Process.cancel_timer(timer_ref)
  end

  def cancel_timer(nil), do: :ok

  @doc """
  Resets the timer (cancels old, starts new).

  Returns the new timer reference.
  """
  def reset_timer(old_timer_ref, duration_seconds \\ @default_timer_duration_seconds) do
    cancel_timer(old_timer_ref)
    start_timer(duration_seconds)
  end
end
