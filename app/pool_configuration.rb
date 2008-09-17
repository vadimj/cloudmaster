require 'named_queue'
require 'ec2_image_enumerator'

module Cloudmaster

#  All configuration parameters passed in through the constructor.
#  Items with * must be defined
#
#  ==aws_config==
#    aws_env -- used to form queue, instance, and s3 key names -- 
#      typically development|test|production
#    *aws_access_key -- the AWS access key
#    *aws_secret_key -- the AWS secret key
#    *aws_user -- the user name, used to build the image name
#    *aws_bucket -- the bucket to use when storing the active set
#    *aws_keypair -- full path name of the keypair file to use for 
#      connecting to instances
#
#  ==config==
#    ===GENERAL===
#    *name -- the name of this config
#    *policy -- :none, :job, :resource
#    ===QUEUES===
#    poll_interval -- how often to check work queue, etc (seconds)
#    receive_count -- how many status messages to receive at once
#    *work_queue -- name of work queue (aws_env)
#    *status_queue -- name of status queue (aws_env)
#    ===ACTIVE SET===
#    active_set_type -- which active set algorithm to use: :none, :s3, :queue
#    active_set_bucket -- the S3 bucket to use to store the active set
#    active_set_key -- the S3 key used to store the active set (aws_env)
#    active_set_interval -- how often to write active_set
#    ===INSTANCE CREATION PARAMETERS===
#    *ami_name -- the ami name to start and monitor (aws_env)
#    key_pair_name -- the name if the keypair to start the instance with
#    security_groups -- array of security group names to start the instance with
#    instance_type -- the smi instance type to create
#    user_data -- instance data made available to running instance 
#        through http://169.254.169.254/latest/user-data
#        This is given as a hash, which is serialized by cloudmaster.
#     
#    ===INSTANCE MANAGEMENT POLICIES===
#    policy_interval -- how often to apply job or resource policy
#    audit_instance_interval -- how often (in minutes) to audit instances (-1 for never)
#    maximum_number_of_instances -- the max number to allow
#    minimum_number_of_instances -- the min number to allow
#    ===INSTANCE START POLICIES===
#    start_limit -- how many instances to start at one time
#    ===INSTANCE STOP POLICIES===
#    stop_limit -- how many to stop at one time
#    minimum_lifetime -- don't stop an instance unless it has run this long (minutes)
#    minimum_active_time -- the minimum amount of time (in minutes) that an instance
#      may remain in the active state
#    watchdog_interval -- if a machine does not report status in this interval, it is
#      considered to be hung, and is stopped
#    ===JOB POLICIES===
#    start_threshold -- if work queue size is greater than start_threshold * number of
#      active instances, start more instances
#    idle_threshold -- if more than idle_threshold active instances with load 0 
#      exist, stop some of them
#    ===RESOURCE POLICIES===
#    target_upper_load -- try to keep instances below this load
#    target_lower_load -- try to keep instances above this load
#    queue_load_factor -- the portion of the load that a single queue entry represents.
#      If a server can serve a maximum of 10 clients, then this is 10.
#    shut_down_threshold -- stop instances that have load_estimate below this value
#    shut_down_interval -- stop instances that have been in shut_down state for
#      longer than this interval
#    ===MANUAL POLICIES===
#    manual_queue_name -- the name of the queue used to send manual instance adjustments
#    ===REPORTING===
#    summary_interval -- how often to give summary 
#    instance_log -- if set, it is a patname to a directory where individual log files
#      are written for each instance
#    instance_report_interval -- how often to show instance reports

  # PoolConfiguration holds the configuration parameters for one pool.
  # It also stores aws parameters and defaults, providing a single lookup mechanism
  # for all.
  # If lookup files, then it raise an exception.

  class PoolConfiguration
    # Create a new PoolConfiguration.  The default parameters
    # are used if the desired parameter is not given.
    def initialize(aws_config, default, config)
      # these parameters merge the defaults and the given parbameters
      # merged parameters are also evaluated
      @merge_params = [:user_data]
      @aws_config = aws_config
      @default = default
      @config = config
    end
    
    # Get a parameter, either from aws_config, config or default.
    # Don't raise an exception if there is no value.
    def get(param)
      @aws_config[param] || @config[param] || @default[param]
    end

    # Get a parameter, either from config or from default.
    # Raise an exception if there is none.
    def [](param)
      if @default.nil?
        raise "Missing defaults"
      end
      config_param = @aws_config[param] || @config[param]
      if (res = config_param || @default[param]).nil?
        raise "Missing config: #{param}"
      end
      begin
        if @merge_params.include?(param)
	 # fix up default param if needed -- it must be a hash
	  @default[param] = {} if @default[param].nil? 
          @default[param] = eval(@default[param]) if @default[param].is_a?(String)
          if config_param 
            @default[param].merge(eval(config_param))
	  else
            @default[param]
	  end
        else
          res
        end
      rescue
        raise "Config bad format: #{param} #{config_param} #{$!}"
      end
    end

    # Store (create or replace) a parameter.
    def []=(param, val)
      @config[param] = val
    end

    def append_env(name)
      aws_env = @aws_config[:aws_env]
      aws_env.nil? || aws_env == '' ? name : "#{name}-#{aws_env}"
    end

    # Test to see that the derived parameters are valid.
    def valid?
      @config[:ami_id] && 
        @config[:work_queue] && @config[:work_queue].valid? && 
        @config[:status_queue] && @config[:status_queue].valid?
    end

    # Looks up a queue given its name.
    # Stores the result in config under the given key (if given).
    # Returns the queue.
    # Raises an exception if none found.
    def setup_queue(key, name)
      return nil unless name
      name = append_env(@config[name])
      queue = NamedQueue.new(name)
      raise "Bad configuration -- no queue #{name}" if !queue
      @config[key] = queue if key
      queue
    end

    # Looks up the image, given its name.
    # Stores the result in config under the given key (if given).
    # Returns the image.
    # Raises an exception if none found.
    def setup_image(key, name)
      return nil unless name
      name = append_env(@config[name]) + ".img"
      image = EC2ImageEnumerator.new.find_image_id_by_name(name)
      raise "Bad configuration -- no image #{name}" if !image
      @config[key] = image if key
      image
    end

  end
end
