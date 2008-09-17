
require 'policy'

module Cloudmaster

  # Provides job policy
  # Instances managed by the job policy take work from a queue and report
  # status thrugh another queue.
  class PolicyJob < Policy
    # Initialize the policy by giving it access to the configuration and 
    # the collection of instances.
    def initialize(reporter, config, instances)
      super(reporter, config, instances)
      @config = config
    end

    # Adjust the pool size.
    # Add instances if the queue is getting backed up.
    # Delete instances if the queue is empty and instances are idle.
    def adjust
      depth = @config[:work_queue].queue_depth

      # See if we should add instances
      if (depth > 0 && @instances.size == 0) || depth >= @config[:start_threshold].to_i
        additional = 0
        # need this many more to service the queued work
        needed = (depth.to_f / @config[:start_threshold].to_f).floor
	needed = 1 if needed < 1
        if needed > @instances.size
          additional = needed - @instances.size
        end
       @reporter.info("Job policy need additional #{additional}  depth: #{depth} needed #{needed}")
       return additional
      end
      
      # Queue not empty -- don't stop any
      return 0 if depth > 0 

      # See if we should stop some
      # count how many are active idle and active
      idle = @instances.active_idle_instances
      active = @instances.active_instances
      if idle.size > 0
        # stop some fraction of the idle instances
        excess = (idle.size / @config[:idle_threshold].to_f).round
        @reporter.info("Job policy need fewer #{excess}  idle: #{idle.size} active #{active.size}")
	return -excess
      end
      0
    end

    # uses the default apply
  end
end