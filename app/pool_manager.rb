require 'periodic'
require 'pp'
require 'logger'
require 'reporter'
require 'instance_pool'
require 'aws_context'
require 'policy_factory'
require 'active_set_factory'
require 'status_parser_factory'
require 'logger_factory'
require 'policy'

module Cloudmaster

#  PoolManager
#
#  Manages one InstancePool, which is collections of EC2 instances 
#  running the same image.  
#  The InstancePoolMaanger is responsible for starting and terminating 
#  instances.
#  It's policies are meant to balance acceptable performance while 
#  minimizing cost.
#  To help achieve this goal, the PoolManager receives 
#  status reports from instances, through a status queue.
#
#  Two classes of policies are defined: job and resource. 
#  These roughly correspond to stateless and stateful services.
#
#  ==Job Policy==
#  In the job policy, instances are assigned work through a work queue.
#  * Each request is stateless, and can be serviceed by any instance.
#  * Each instance processes one request at a time.
#  * Each instance is either starting_up or active.  
#  * Once it is active, it is either busy (load 1.0) or idle (load 0.0).
#  At startup, the instance reports when it is ready to begin processing, and
#  enters the active state.
#  Each instance reports the load through the status queue when it 
#  starts/stops processing a job.
#
#  The job policy aims to keep the work queue to a reasonable size while not
#  maintaining an excessive number of idle instances.
#
#  ==Resource Policy==
#  Instance managed by theresource policy have stateful associations with 
#  clients, and provide them services on demand.  
#  * Each instance processes requests made by clients as requested.
#  * An external entity (the alllocator) assigns clients to instances 
#    based on an instance report, which  lists the active instances 
#    and their associated load.  
#  * The instance report (called the active set) is stored in
#    S3, at a configurable bucket and key.
#  * The allocator assigns clients to instances, and also creates a 
#    work-queue entry each time it assigns a new client.
#  * The allocator is expected to assign clients only to those instances 
#    listed in the active set.
#  *  The work queue is emptied by cloudmaster.
#  *  Each instance may be starting_up, active, or shutting_down.
#  *  At startup, the instance reports when it is ready to begin processing, 
#     and enters the active state.
#  *  The policy decides when to shut down an instance.  
#     It puts it in the shut_down state, but does not stop
#     it immediately (to avoid disturbing existing clients).
#     Instances in shutting_down state with zero load, or who have
#     remained in this state for an excessive time are stopped.
#  *  Active instances are available to accept new clients; 
#     shutting_down instances are not.
#  During any given time period, each instance can be partially busy (load 
#  between 0.0 and 1.0)
#  Each instance periodically reports is load estimate for that period through 
#  the status queue.
#  The resource policy seeks to maintain a load between an 
#  upper threshold and a lower threshold.  
#  It starts instances or stops them to achieve this.

  class PoolManager
    attr_reader :instances, :logger     # for testing only

    # Set up PoolManager.
    # Creates objects used to access SQS and EC2.
    # Creates instance pool, policy classes, repoter, and queues.
    # Actual processing does not start until "run" is called.
    def initialize(config)
      # set up AWS access objects
      keys = [ config[:aws_access_key], config[:aws_secret_key]]
      aws = AwsContext.instance
      @ec2 = aws.ec2(*keys)
      @sqs = aws.sqs(*keys)
      @s3 = aws.s3(*keys)
      @config = config

      # set up reporter
      @logger = LoggerFactory.create(@config[:logger], @config[:logfile])
      @reporter = Reporter.setup(@config[:name], @logger)

      # Create instance pool.
      # Used to keep track of instances in the pool.
      @instances = InstancePool.new(@reporter, @config)

      # Create a policy class
      @policy = PolicyFactory.create(@config[:policy], @reporter, @config, @instances)

      # Create ActiveSet
      @active_set = ActiveSetFactory.create(@config[:active_set_type], @config)

      # Create StatusParser
      @status_parser = StatusParserFactory.create(@config[:status_parser])

      unless @config[:instance_log].empty?
        @reporter.log_instances(@config[:instance_log])
      end

      # Look up the work queues and the image from their names.
      # Have policy do most of the work.
      @work_queue = @config.setup_queue(:work_queue, :work_queue_name)
      @status_queue = @config.setup_queue(:status_queue, :status_queue_name)
      @ami_id = @config.setup_image(:ami_id, :ami_name)

      @keep_running = true
    end
    
    # Main loop of cloudmaster
    # 
    # * Reads and processes status messages.
    # * Starts and stops instances according to policies
    # * Detects hung instances, and stops them.
    # * Displays periodic reports.
    def run(end_time = nil)
      summary_period = Periodic.new(@config[:summary_interval].to_i)
      instance_report_period = Periodic.new(@config[:instance_report_interval].to_i)
      policy_period = Periodic.new(@config[:policy_interval].to_i)
      active_set_period = Periodic.new(@config[:active_set_interval].to_i * 60)
      audit_instances_period = Periodic.new(@config[:audit_instance_interval].to_i * 60)

      # loop reading messages from the status queue
      while keep_running(end_time) do
        # upate instance list and get queue depth
	audit_instances_period.check do
          @instances.audit_existing_instances
	end

        @work_queue.read_queue_depth
        break unless @keep_running

        # start first instance, if necessary, and ensure the
        #  number of running instances stays between maximum and minimum
        @policy.ensure_limits
        break unless @keep_running

        # handle status and log messages
        process_messages(@config[:receive_count].to_i)
		    
        # update public dns (for new instances) and show summary reports
        @instances.update_public_dns_all
        summary_period.check do
          @reporter.info("Instances: #{@instances.size} Queue Depth: #{@work_queue.queue_depth}")
        end
        instance_report_period.check do
          @reporter.info("---Instance Summary---")
          @instances.each do |instance|
            @reporter.info("  #{instance.id} #{instance.report}\n")
          end
          @reporter.info("----------------------")
        end
        break unless @keep_running
        
        # Based on queue depth and load_estimate, make a decision on
        # whether to start or stop servers.
        policy_period.check { @policy.apply }

        active_set_period.check { update_active_set }

        # Stop instances that have not given recent status.
        @policy.stop_hung_instances
        break unless @keep_running

        Clock.sleep @config[:poll_interval].to_i
      end
    end
    
    # Shut down the manager.
    # This may take a little time.
    def shutdown
      @keep_running = false
    end

  private

    # Process a batch of status and log messaage.
    # Status messages update the instance usage information, and
    # log messages are just logged.
    # Observed behavior is that only one message is returned per call
    # to SQS, no matter how many are requested.
    def process_message_batch(count)
      # read some messages
      messages = @status_queue.read_messages(count)
      messages.each do |message|
        # parse message 
	msg = @status_parser.parse_message(message[:body])
        case msg[:type]
        when "status"
          # save the status and load_estimate
          @instances.update_status(msg)
        when "log"
          # just log the message
          @reporter.info(msg[:message], msg[:instance_id])
        end
        # delete the message once it has been processed
        @status_queue.delete_message(message[:id])
      end
      messages.size
    end
    
    # Process messages (up to count)
    # Continue until there are no messages remaining.
    def process_messages(count)
      n_remaining = count
      while n_remaining > 0
        n = process_message_batch(n_remaining)
        break if n == 0
        n_remaining -= n
      end
    end
    
    # Write active set if it has changed since the last write.
    def update_active_set
       @active_set.update(@instances.active_set)
    end

    # Returns true if the manager should keep running.
    def keep_running(end_time)
      if end_time && Clock.now > end_time
        false
      else
        @keep_running
      end
    end

  end
end
