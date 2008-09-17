#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__))

require 'basic_configuration'
require 'aws_context'
require 'pp'
require 'yaml'

#  Allocates work to servers in the active-set.
#  This is a sample of how a resource pool can be managed.
#
#  Reads the active-set from S3, finds the lowest load, and
#  allocates work to that server.
#  If there is no active server running, then the allocation
#  request fails, but a message is sent to the work queue to
#  cause an instance to be started.  Presumably subsequent
#  requests will succeed (after the server gets to the active state).
class Allocator
  def initialize(bucket, s3_key, work_queue_name)
    config = BasicConfiguration.new
    @s3 = AwsContext.instance.s3(*config.keys)
    @sqs = AwsContext.instance.sqs(*config.keys)

    @bucket = bucket
    @key = s3_key

    @work_queue = @sqs.list_queues(work_queue_name).first
    if @work_queue.nil? 
      puts "queue not found: #{work_queue_name}"
    end
  end
  
  # Get the active servers from the active-set
  def get_active_set
    body = ''
    obj = @s3.get_object(@bucket, @key) do |data|
      body << data
    end
    @active_set = YAML.load(body)
  end
  
  #  Send a message to the work queue each time work is allocated
  #  to a server.
  #  This is done when work is actually allocated, or when there is no
  #  server running.
  def send_work(message)
    body = message
    res = @sqs.send_message(@work_queue, body)
  end

  # Assign a new client to a server
  # If there are no active servers, send a work request, and return
  # If there are, assign to the least loaded and send work-queue request.
  def new_client
    active_set = get_active_set
    if active_set.size == 0
      # no server, the request fails
      send_work("startup")
      nil
    else
      lowest = active_set.min do |a, b|
        a[:load_estimate] <=> b[:load_estimate]
      end
      # return the pubic dns of the instance with the lowest load
      lowest[:public_dns]
    end
  end  
end
