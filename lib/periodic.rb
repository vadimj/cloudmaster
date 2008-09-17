  #  Used to execute tasks periodically.
  #  Execute at most once each interval (seconds).
  #  If interval is < 0, never execute.
  #  If interval is 0, execute every time.
  class Periodic
    # Create a periodic execution at this interval.
    def initialize(interval)
      @last_time = Clock.at(0)
      @interval = interval
    end

    # Runs if it has not executed in the interval,.
    # Skip otherwise.
    def check    #expects a block
      case
      when @interval < 0
        return
      when @interval == 0
        yield
      when @interval > 0
        now = Clock.now
        if (@last_time + @interval) < now
          yield
          @last_time = now
        end
      end
    end
  end
  