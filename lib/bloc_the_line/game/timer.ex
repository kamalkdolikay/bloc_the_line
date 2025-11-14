defmodule GameTimer do

  # default game timer
  @default_timer_duration_seconds 300

  def start_timer(duration_seconds \\ @default_timer_duration_seconds) do
    Process.send_after(self(), :game_over_timeout, duration_seconds * 1000)
  end

end
