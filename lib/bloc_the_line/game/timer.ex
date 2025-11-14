defmodule GameTimer do

  # default game timer
  @default_timer_duration_seconds 300

  def start_timer(duration_seconds \\ @default_timer_duration_seconds) do
    Process.send_after(self(), :game_over_timeout, duration_seconds * 1000)
  end

  def cancel_timer(timer_ref) when is_reference(timer_ref) do
    Process.cancel_timer(timer_ref)
  end

  def cancel_timer(nil), do: :ok

  def reset_timer(old_timer_ref, duration_seconds \\ @default_timer_duration_seconds) do
    cancel_timer(old_timer_ref)
    start_timer(duration_seconds)
  end

end
