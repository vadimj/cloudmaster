require 'aws_context'
require 'ec2_instance_enumerator'
require 'instance'
require 'yaml'

module Cloudmaster

  #  Stores and operates on a collection of instances
  #  
  #  Internally, instances are stored as an array of Instance objects.
  class InstancePool
    include Enumerable

    # Create an instance pool.  
    # This class knows how to start and stop instances, and how to detect
    # that new instance have come about, or existing ones have gone away.
    # The constructor takes:
    #   [config] describes configurable instance properties
    def initialize(reporter, config)
      @ec2 = AwsContext.instance.ec2
      @reporter = reporter
      @config = config
      @state_change_time = Clock.now
      @instances = []         # holds Instance objects
    end

#    private

    # Create and return options, in a way that is acceptable to EC2.
    def start_opts
      groups = @config[:security_groups]
      # this can throw an exception if groups is not formetteed properly
      begin
        groups = eval(groups) if groups.kind_of?(String)
      rescue
        groups = [:default]
      end
      {:key_name => @config[:key_pair_name], 
          :user_data => YAML.dump(@config[:user_data]), 
          :security_groups => groups, 
          :instance_type => @config[:instance_type]}
    end

    def max2(a, b)
      a > b ? a : b
    end

    # Allows iteration through instances.
    # So enumeration on InstancePool is implicitly enumeration
    #  on @instances.
    def each
      @instances.each {|i| yield i}
    end

    # return first instance
    def first
      @instances.first
    end

    # Return the number of instances in the pool.
    def size
      @instances.size
    end

    # Create an instance and add to the list.
    # Return the newly created instance.
    def add(id, public_dns)
      new_instance =  Instance.new(id, public_dns, @config)
      @instances << new_instance
      new_instance
    end

    # Delete the instance from the list
    def delete(instance)
      @instances.delete(instance)
    end

    # Find an instance given its instance id.
    def find_by_id(id)
      find {|i| i.id == id}
    end

    # Return a list of all instance ids.
    def id_list
      map {|i| i.id}
    end

    # Return the maximum number of instances allowed.
    def maximum
      @config[:maximum_number_of_instances].to_i
    end

    # Return the minimum number of instances allowed.
    def minimum
      @config[:minimum_number_of_instances].to_i
    end

    # Return true if the number of instances is less than the minimum.
    def less_than_minimum?
      size < minimum
    end

    # return true if number of instances is more than maximum
    def greater_than_maximum?
      size > maximum
    end

    # Return count of instance below minimum
    def below_minimum_count
      less_than_minimum? ? minimum - size : 0
    end

    # Return count of instance above maximum
    def above_maximum_count
      greater_than_maximum? ? size - maximum : 0
    end

    # Return a list of instances missing public_dns.
    def missing_public_dns_instances
      find_all {|i| i.public_dns.nil? || i.public_dns.empty? }
    end

    # Return ids of all instances missing a public_dns.
    def missing_public_dns_ids
      missing_public_dns_instances.collect {|i| i.id}
    end

    # Find the instance identified by id and update its public_dns
    # If there is no dns information, then skip it.
    def update_public_dns(id, public_dns)
      return if public_dns.nil? || public_dns.empty?
      i = find_by_id(id)
      i.public_dns = public_dns if i
    end

    # Return instances that have not seen status in watchdog_interval
    def hung_instances
      find_all {|i| i.watchdog_time_elapsed?}
    end

    # Return all instances in active state
    def active_instances
      find_all {|i| i.state == :active}
    end

    # Return all instances in shut_down state
    def shut_down_instances
      find_all {|i| i.state == :shut_down}
    end

    # Return instances that are active and have load <= target_load
    def active_idle_instances
      target_load = 0
      active_instances.find_all {|i| i.load_estimate <= target_load}
    end

    # Shut down all instances who have a load below the target.
    # Shut down is not the same as stop -- the instances continue to
    # provide service, but are no longer allocated new clients.
    def shut_down_idle_instances
      target_load = @config[:shut_down_threshold].to_i
      shut_down_instances.find_all {|i| i.load_estimate <= target_load}
    end

    # Return instances that are shut_down and have 
    # time_since_state_change > shut_down_interval.
    def shut_down_timeout_instances
      shut_down_interval = @config[:shut_down_interval].to_i * 60

      shut_down_instances.find_all {|i| i.time_since_state_change > shut_down_interval}
    end

    # Return the latest time since any state change of any instance.
    def state_change_time
      @state_change_time = inject(@state_change_time) do |latest, instance|
        max2(latest, instance.state_change_time)
      end
    end

    # Return the sum of all the extra capacity of active instances
    # that have excess capacity (load less than target load).
    def excess_capacity
      target_load = @config[:target_upper_load].to_f
      active_instances.inject(0) do |sum, instance|
        sum + max2(target_load - instance.load_estimate, 0)
      end
    end

    # Return the sum of capacity in excess of the target upper load
    def over_capacity
      target_load = @config[:target_upper_load].to_f
      active_instances.inject(0) do |sum, instance|
        sum + max2(instance.load_estimate - target_load, 0)
      end
    end

    # Return the total load of all active instances
    def total_load
      active_instances.inject(0) do |sum, instance|
        sum + instance.load_estimate
      end
    end

    # Update the status of an instance using the contents of the status message.
    def update_status(msg)
      id = msg[:instance_id]
      if instance = find_by_id(id)
        instance.update_status(msg)
      else
        @reporter.error("Received status message from unknown instance: #{id}") unless id == 'unknown'
      end
    end

    # Return a YAML encoded representation of the active set.
    # The active set describes the id, public DNS, and load average of
    # each active instance in the pool.
    def active_set
      message = active_instances.collect do |instance|
        { :id => instance.id, 
          :public_dns => instance.public_dns, 
          :load_estimate => instance.load_estimate }
      end
      YAML.dump(message)
    end

    # Return all the instance, sortd by lowest load estimate.
    def sorted_by_lowest_load
      @instances.sort do |a,b|
        # Compare the elapsed lifetime status. If the status differs, instances
        # that have lived beyond the minimum lifetime will be sorted earlier.
        if a.minimum_lifetime_elapsed? != b.minimum_lifetime_elapsed?
          if a.minimum_lifetime_elapsed?
            -1   # This instance has lived long enough, the other hasn't
          else
            1    # The other instance has lived long enough, this one hasn't
          end
        else
          a.load_estimate - b.load_estimate
        end
      end
    end

    # Find all instances for which we don't have a public_dns,
    # For each one,see of EC2 now has the public DNS.  If so, store it.
    def update_public_dns_all
      missing_ids = missing_public_dns_ids
      return if missing_ids.size == 0
      EC2InstanceEnumerator.new(missing_ids).each do |instance|
        update_public_dns(instance[:id], instance[:public_dns])
      end
    end

    # Return instances that match our ami_id that are either pending
    # or running.
    # These instances are as returned by ec2: containing fields such as
    # id and :public_dns.
    def our_running_instances
      EC2InstanceEnumerator.new.find_all do |instance|
        instance[:image_id] == @config[:ami_id] && 
          %w[pending running].include?(instance[:state])
      end
    end

    # Audit the list of instances based on what is currently known to EC2.
    # In other words, bring our list of instances into agreement with the instances
    # EC2 knows about by
    # (1) adding instances that EC2 knows but that we do not, and
    # (2) deleting instance that EC2 no longer knows about.
    # This is used initially to build the instance list, and
    # periodically thereafter to catch instances started or stopped
    # outside cloudmaster.
    def audit_existing_instances
      running_instances = our_running_instances
      
      # add running instances that we don't have
      running_instances.each do |running|
        if ! find_by_id(running[:id])
          add(running[:id], running[:public_dns])
          @reporter.info("Instance discovered #{running[:public_dns]}", running[:id])
        end
      end
      # delete instances that are no longer running
      each do |instance|
        if ! running_instances.find {|running| running[:id] == instance.id}
          delete(instance)
          @reporter.info("Instance disappeared #{instance.public_dns}", instance.id)
        end
      end
    end
 
    # Start the given number of instances.
    # Remember started instances by creating an Instance object and storing it
    # in the pool.
    # Return an array of the ones we just started.
    def start_n_instances(number_to_start)
      return [] if number_to_start <= 0 
      started_instances = @ec2.run_instances(@config[:ami_id], 1, 
                               number_to_start, start_opts)[:instances]
      started_instances.collect do |started_instance|
        # the public dns is not available yet
        add(started_instance[:id], nil)
      end
    end
    
    # Stop the given set of instances.
    # Remove stopped instance from the pool.
    # Return an array of stopped instances.
    def stop_instances(instances_to_stop)
      instances_to_stop.collect do |instance|
        @ec2.terminate_instances(instance.id.to_s)
        delete(instance)
        instance
      end
    end

    # Shut down the given set of instances.
    # Set the state to shut_down
    # Return an array of shut down instances.
    def shut_down(instances_to_shut_down)
      instances_to_shut_down.collect do |instance|
        instance.shutdown
        instance
      end
    end
  end
end