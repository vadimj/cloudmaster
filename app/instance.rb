module Cloudmaster

  # Holds information about a specific instance.
  # When we create an instance in EC2, we create one of these classes to hold
  # information about the instance.  Instances are members of the InstancePool.
  #
  # Each instance holds the following information:
  #  * id -- instance id
  #  * public_dns -- the public dns name of the instance
  #  * load_estimate -- last reported load -- between 0 and 1
  #  * state -- startup, active, shut_down
  #  * start_time -- (local) time when the instance was started
  #  * last_status_time -- (local) time when the last status was received
  #  * last_timestamp -- (remote) timestamp of last report
  #
  # The state here differs from the EC2 state.  We only track instances in
  # EC@ state pending or running.  Our state is controlled by status messages
  # received and by stop policies.
  class Instance
    attr_reader :id, :load_estimate, :state, :state_change_time
    attr_accessor :public_dns
    attr_accessor :load_estimate, :state   # for testing only
    attr_reader :status_time, :timestamp   # for testing only
    
    # Create an instance object, reflecting some instance that was stated
    # or discovered running.
    # New instance objects know their instance id, their public DNS (once this is known) and their load estimate.
     def initialize(id, public_dns, config)
      @config = config
      @id = id
      @public_dns = public_dns
      @load_estimate = 0
      @start_time = @status_time = Clock.now
      @active_time = Clock.at(0)
      @state_change_time = Clock.now
      @timestamp = Clock.at(0)
      @state = :startup
    end
    
    # Return a report of the instance's state, load estimate, and time 
    # since the last status message was received.
    def report
      "State: #{@state} Load: #{sprintf("%.2f", @load_estimate)} Time Since Status: #{time_since_status.round}"
    end

    def update_state(state)
      old_state, @state = @state, state
      @state_change_time = Clock.now
      if old_state != :active && @state == :active
	@active_time = Clock.now
      elsif @old_state == :active && @state != :active
	@active_time = Clock.at(0)
      end
    end

    # Update the state and estimated load based on status message
    # Ignore the status message if it was sent earlier than
    # one we have already processed.  This is important, because
    # SQS routinely delivers messages out of order.
    def update_status(msg)
      if message_more_recent?(msg[:timestamp])
        @timestamp = msg[:timestamp]
        @status_time = Clock.now
	update_state(msg[:state].to_sym) if msg[:state] 
        @load_estimate = msg[:load_estimate] if msg[:load_estimate]
      end
    end

#    private
    
    # Return true if the given timestamp is more recent than the last.
    # This calculation takes place with times from the <b>sender's</b>
    # clock.  In other words, it is comparing values based on two timestamps
    # created by the message sender.
    def message_more_recent?(timestamp)
      ! timestamp.nil? && timestamp > @timestamp
    end

    # Return the number of seconds since the last message was received.
    # This uses local time only.
    def time_since_status
      Clock.now - @status_time
    end

    # Return the number of seconds since the last status message with
    # a state field in it.  This uses local times only.
    def time_since_state_change
      Clock.now - @state_change_time
    end

    # Return the number of seconds since the instance was started.
    def time_since_startup
      Clock.now - @start_time
    end

    # Return the number of seconds since the instance became active.
    def time_since_active
      Clock.now - @active_time
    end

    public

    # Return true if the instance has lived at least as long
    # as its minimum lifetime.
    def minimum_lifetime_elapsed?
    lifetime = @config[:minimum_lifetime].to_i * 60
    return true if lifetime <= 0
    time_since_startup > lifetime
    end
    
    # Return true if the instance has been active at least as long
    # as its minimum active time.
    def minimum_active_time_elapsed?
    active_time = @config[:minimum_active_time].to_i * 60
    return true if active_time <= 0
    time_since_active > active_time
    end
    
    # Return true if the instance has lived and has been active for its
    # respective minimum times.
    def minimum_time_elapsed?
      minimum_lifetime_elapsed? && minimum_active_time_elapsed?
    end

    # Return true if the instance has not received a status message
    # in the watchdog interval.
    def watchdog_time_elapsed?
      interval = @config[:watchdog_interval].to_i * 60
      return false if interval <= 0
      time_since_status > interval
    end

    # Shut down an instance by putting it in the "shut_down" state.
    # After this is can either be activated again or stopped.
    def shutdown
      update_state(:shut_down)
    end

    # Make the instance active.  This is usually done after the
    # instance is shut down, but before it is stopped, it needs to
    # become active again.
    def activate
      update_state(:active)
    end
  end
end
