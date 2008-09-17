
require 'policy'

module Cloudmaster

  # Provides resource policy implementation.
  # Instances managed under a resource policy are expected to issue
  # periodic status messages, giving their estimated load (generally
  # between 0 and 1).
  class PolicyResource < Policy
    # Each policy object gets the configuration and the instance collection.
    def initialize(reporter, config, instances)
      super(reporter, config, instances)
      @config = config
    end

    # Activate the given number of shut_down instances.
    # We prefer those with highest load.
    # Return the number actually activated.
    def activate_shut_down_instances(number_to_activate)
      shutdown_instances = @instances.shut_down_instances.sort do |a,b|
        b.load_estimate - a.load_estimate
      end
      shutdown_instances = shutdown_instances[0..number_to_activate]
      shutdown_instances.each { |i| i.activate }
      shutdown_instances.each { |i| @reporter.info("Activating instance ", i.id) }
      shutdown_instances.size
    end

    # Shut down the given instances, by changing their state to shut_down.
    def shut_down_instances(instances_to_shut_down)
      instances = @instances.shut_down(instances_to_shut_down)
      instances.each {|i| @reporter.info("Shutting down instance ", i.id) }
      instances.size
    end

    # Shut down the given number of instances.
    # Shut down the ones with the lowest load.
    def shut_down_n_instances(number_to_shut_down)
      return if number_to_shut_down <= 0
      instances_with_lowest_load = @instances.sorted_by_lowest_load
      instances_to_shut_down = instances_with_lowest_load.find_all do |instance|
        # Don't stop instances before minimum_active_time
        instance.minimum_active_time_elapsed?
      end
      shut_down_instances(instances_to_shut_down[0...number_to_shut_down])
    end

    # Stop any shut down instances with load below threshold.
    # Also stop instances that have exceeded shut_down_interval.
    def clean_up_shut_down_instances
      idle_instances = @instances.shut_down_idle_instances
      timeout_instances = @instances.shut_down_timeout_instances
      stop_instances(idle_instances | timeout_instances)
    end

    # Adjust the instance pool up or down.
    # If no instance are running, and there are requests in the work queue, start
    # some.
    # Additional instances are added if the load is too high.
    # Instances are shut down, and then stopped if the load is low.
    def adjust
      depth = @config[:work_queue].empty_queue
      if @instances.active_instances.size == 0
        # capacity consumed by new arrivals
        new_load = depth.to_f / @config[:queue_load_factor].to_f
        initial = (new_load / @config[:target_upper_load].to_f).ceil
	@reporter.info("Resource policy need initial #{initial}  depth: #{depth} new_load #{new_load}") if initial > 0
        return initial
      end
      if depth > 0
	@reporter.info("Resource policy residual depth: #{depth}")
	return 0
      end
      # the total capacity remaining below the upper bound
      excess_capacity = @instances.excess_capacity
      if excess_capacity == 0
        # need this many more running at upper bound
	over_capacity = @instances.over_capacity
        additional = (over_capacity / @config[:target_upper_load].to_f).ceil
	@reporter.info("Resource policy need additional #{additional}  depth: #{depth} over_capacity #{over_capacity}")
        return additional
      end
      # how many are needed to carry the total load at the lower bound
      needed = (@instances.total_load / @config[:target_lower_load].to_f).ceil
      if needed < @instances.size
        excess = @instances.size - needed
	@reporter.info("Resource policy need fewer #{excess}  depth: #{depth} needed #{needed}")
	return -excess
      end
      return 0
    end

    # We are not using the default apply, because we want to:
    #  * activate shut down instances, if posible, otherwise start
    #  * shut down instances if fewer are needed
    #  * stop inactive or expired shut_down instances
    def apply
      n = @limit_policy.adjust(adjust)
      case 
      when n > 0
        n -= activate_shut_down_instances(n)
        start_instances(n)
      when n < 0
        shut_down_n_instances(-n)
      end
      clean_up_shut_down_instances
    end
  end
end