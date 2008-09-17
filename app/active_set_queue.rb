require 'aws_context'

# This implementation of ActiveSet writes the active set to a queue

module Cloudmaster
  class ActiveSetQueue
    def initialize(config)
      @sqs = AwsContext.instance.sqs
      active_set_queue_name = config.append_env(config[:active_set_queue])
      @active_set_queue = NamedQueue.new(active_set_queue_name)
    end

    private

    public

    def valid?
      ! @active_set_queue.nil?
    end

    def update(active_set)
      body = active_set
      body = ' ' if body.empty?
      @sqs.send_message(@active_set_queue, body)
    end
  end
end
