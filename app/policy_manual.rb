require 'policy'

module Cloudmaster

  # Provide manual policy.
  # This policy only changes the instances when requested to do so.
  # This implementation uses a queue to convey manual requests
  # to the policy module.
  class PolicyManual < Policy
    def initialize(reporter, config, instances)
      super(reporter, config, instances)
      @config = config
      @sqs = AwsContext.instance.sqs
      manual_queue_name = @config.append_env(config[:manual_queue_name])
      @manual_queue = NamedQueue.new(manual_queue_name)
    end

    # Adjust never changes instances.
    def adjust
      n = 0
      # Read all the messages out of the manual queue.
      # Sum up all adjustments.
      while true
        messages = @manual_queue.read_messages(10)
	break(n) if messages.size == 0
        messages.each do |message|
          msg = YAML.load(message[:body])
          n += msg[:adjust]
	  @manual_queue.delete_message(message[:id])
        end
      end
      # the value of the while is n
    end
  end

end