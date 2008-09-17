require 'policy_limit'

module Cloudmaster

  # Provides the common data and behaviors for policies.
  # This includes storing the configuration and instance collection.
  # It also includes implementing essential methods such as ensure_limite and
  # stop_hung_instances.
  # Finally, this implements helpers that process the queue and image names
  # which might be desirable to override.
  class Policy
    def initialize(reporter, config, instances)
      @reporter = reporter
      @config = config
      @instances = instances
      @limit_policy = PolicyLimit.new(reporter, config, instances)
    end

    # Make sure there are at least the minimum instances running.
    # Also make sure there are no more than maximum number of instances.
    # If not, start or stop enough to conform.
    # These actions bypass the creation and termination limits normally in place
    def ensure_limits
      n = @limit_policy.adjust_limits
      case
      when n > 0
        start_instances(n) 
      when n < 0
        stop_instances(-n) 
      end
    end

    # If instances have not sent status in a long time, they
    # are probably hung, and should be stopped.
    def stop_hung_instances
      if @instances.hung_instances.size > 0
        @reporter.info("Stopping hung instances #{@instances.hung_instances.size}")
        stop_instances(@instances.hung_instances)
      end
    end

    # Default policy application function
    # Calculate the number to adjust by, and then start or
    # stop instances accordingly.
    def apply
      n = @limit_policy.adjust(adjust)
      case 
      when n > 0
        start_instances(n)
      when n == 0
        0
      when n < 0
        stop_instances(-n)
      end
    end

    # Returns the number of additional instances to start (positive)
    # or the number to stop (negative)
    # This must be implemented by derived class.
    def adjust
      raise NotImpelemntedError("#{self.class.name}#adjust is not implemented.")
    end

    protected

    # Start the given number of instances.
    # Return the number started.
    def start_instances(number_to_start)
      started_instances = @instances.start_n_instances(number_to_start)
      if started_instances.size < number_to_start
        @reporter.error("Failed to start requested number of instances. (#{started_instances.size} instead of #{number_to_start})")
      end
      started_instances.each { |started| @reporter.info("Started instance #{started.id}")}
      started_instances.size
    end

    # Stop the given list of instances.
    # Don't stop ones whose minimum lifetime has not elapsed.
    # Returns the number stopped.
    def stop_instances_list(instances_to_stop, force = false)
      instances_to_stop = instances_to_stop.find_all do |instance|
        # Don't stop instances before minimum_time
        force || instance.minimum_time_elapsed?
      end
      instances = @instances.stop_instances(instances_to_stop)
      instances.each {|i| @reporter.info("Terminating instance ", i.id) }
      instances.size
    end

    # Stop a given number of instances.
    # Return the number stopped.
    def stop_n_instances(number_to_stop)
      return if number_to_stop <= 0
      # stop the instances with the lowest load estimate
      instances_with_lowest_load = @instances.sorted_by_lowest_load
      stop_instances_list(instances_with_lowest_load[0...number_to_stop])
    end

    # Stop instances.
    # If passed a number, it stops that number of instances.
    # If passed a list of instance ids, it stops those instances.
    def stop_instances(to_stop, *params)
      if to_stop.class == Fixnum
        stop_n_instances(to_stop)
      elsif to_stop.class == Array
        stop_instances_list(to_stop, *params)
      else
        raise "Bad call -- stop_instances #{to_stop.class}"
      end
    end
  end

end
