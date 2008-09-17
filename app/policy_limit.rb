module Cloudmaster

  # This enforces the limits on starting and stopping instances.
  # It can be used by other policies to make sure thrie own adjust method
  # does not increase or decrease by more than the configurable start limit or stop limit.
  # This also provides an exaplanation for its actions.
  class PolicyLimit
    def initialize(reporter, config, instances)
      @reporter = reporter
      @config = config
      @instances = instances
    end

    def max2(a, b)
      a > b ? a : b
    end

    # Make sure there are at least the minimum instances running.
    # Also make sure there are no more than maximum number of instances.
    # Return the number to start (positive) or stop (negative) to stay within the limits.
    # Do not enforce start_limit and stop_limit.
    def adjust_limits
      if @instances.less_than_minimum?
        number_to_start = @instances.below_minimum_count
	@reporter.info("Less than minimum -- start more #{number_to_start}")
        number_to_start
      elsif @instances.greater_than_maximum?
        number_to_stop = @instances.above_maximum_count
	@reporter.info("Greater than maximum -- stop some #{number_to_stop}")
        -number_to_stop
      else
        0
      end
    end

    # After other policies have computed a value for adjust, then this one possibly
    # modifies the value by ensuring that the start_limit and stop_limit constraints are
    # honored.  It also makes sure that the adjustment makes the instance count
    # stay between the minimum and maximum.
    def adjust(n)
      case
      when n > 0 
        start_limit = @config[:start_limit].to_i
	if n > start_limit
	  @reporter.info("Limit start -- requested: #{n} limit: #{start_limit}")
	  n = start_limit
	end
	remaining = max2(@instances.maximum - @instances.size, 0)
	if n > remaining
	  @reporter.info("Limit start -- requested: #{n} remaining: #{remaining}")
	  n = remaining
	end
      when n < 0 
        stop_limit = @config[:stop_limit].to_i
	if -n > stop_limit
	  @reporter.info("Limit stop -- requested: #{-n} limit: #{stop_limit}")
	  n = -stop_limit
	end
	remaining = max2(@instances.size - @instances.minimum, 0)
	if -n > remaining
	  @reporter.info("Limit stop -- requested: #{n} remaining: #{remaining}")
	  n = -remaining
	end
      end
      n
    end
  end
end
