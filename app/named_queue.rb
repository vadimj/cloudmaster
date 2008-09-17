require 'aws_context'

module Cloudmaster

  # Implements a queue specified by name.
  # The queue name is used to look up the actual SQS queue.
  # The queue name is used in a substring match, so possibly more than one
  # string may match.
  # If no queue is found for given name, or if there are
  # multiple, the NamedQueue throws an exception.
  # Implements the read and delete operations.
  # It also caches queue_depth, so it need not query SQS every time
  # it is needed.
  class NamedQueue
    attr_reader :queue_depth

    # Create a queue given the queue name.
    # A SQS interface must be supplied: it is used to interact with Amazon.
    # The queue name is given, and is used to look up the actual queue.
    # Raises an exception if there is more than one queue matching the given
    # name.
    # If there is no queue with the given name, create one.
    def initialize(queue_name)
      @sqs = AwsContext.instance.sqs
      queues = @sqs.list_queues(queue_name)
      @queue_depth = 0
      @queue = case queues.length
        when 0
	  queue = @sqs.create_queue(queue_name)
          raise "Bad Configuration -- no queue: #{queue_name}" if queue.nil?
	  queue
        when 1
          queues.first
        else
          raise "Bad configuration -- multiple queues match #{queue_name}"
        end
    end

    # Read some messages off a queue.
    # For some reason, we never receive more than 1.
    # But we are prepared for more.
    # return an array of the messages that were read.
    def read_messages(count = 1)
      @sqs.receive_messages(@queue, count)
    end
    
    # Delete a message from the queue given its id.
    def delete_message(id)
      @sqs.delete_message(@queue, id)
    end

    # Read and discard all messages on the queue.
    # Return the number read.
    def empty_queue
      n = 0
      while true
        msgs = read_messages
        break if msgs.size == 0
        n += 1
        msgs.each {|msg| delete_message(msg[:id])}
      end
      n
    end

    # Get qeue depth and store it.
    # In case of failure, keep the old value.
    # The last value read is available through the queue_depth attribute.
    def read_queue_depth
      attr = 'ApproximateNumberOfMessages'
      attrs = @sqs.get_queue_attributes(@queue, attr)
      @queue_depth = attrs[attr] if attrs.has_key?(attr)
      @queue_depth
    end
  end
end
