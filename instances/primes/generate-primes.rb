$:.unshift File.join(File.dirname(__FILE__))
$:.unshift File.join(ENV['HOME'], 'lib')
require 'aws_context'
require 'user_data'
require 'pp'
require 'open-uri'
require 'yaml'
require 'primes'

# TODO use the log factory

#  Manages generation of primes.
#  Pulls jobs from a SQS primes-work queue one at a time.
#  Computes the given number of primes.

if ARGV.size >= 1
  log = File.new(ARGV[0], "a")
end
log = log || STDERR

class PrimeGenerator
  # initialize queues from names
  def initialize(instance_id, keys, 
      work_queue_name, status_queue_name, log)
    @log = log
    @instance_id = instance_id
    @shutdown = false
    @sqs = AwsContext.instance.sqs(*keys)
    @state = "none"
    @last_status_time = Time.now

    begin
      @work_queue = @sqs.list_queues(work_queue_name).first
      if @work_queue.nil?
        @log.puts "error #{$!} #{work_queue_name}"
        raise "no work queue"
      end
      @status_queue = @sqs.list_queues(status_queue_name).first
      if @status_queue.nil?
        @log.puts "error #{$!} #{status_queue_name}"
        raise "no status queue"
      end
    rescue
      @log.puts "error #{$!}"
      raise "cannot list queues"
    end
    set_state("idle")
  end

  def send_status_message(status)
    now = Time.now
    msg = { :type => 'status',
      :instance_id => @instance_id, 
      :state => 'active',
      :load_estimate => status == 'busy' ? 1 : 0,
      :timestamp => now}
    @sqs.send_message(@status_queue, YAML.dump(msg))
    @last_status_time = now
  end

  def send_log_message(message)
    @log.puts message
    msg = { :type => 'log', 
      :instance_id => @instance_id, 
      :message => message,
      :timestamp => Time.now}
    @sqs.send_message(@status_queue, YAML.dump(msg))
  end

  # Send status when state changes, when state becomes busy, or
  # every minute (even if there is no state change).
  def set_state(new_state)
    if new_state != @state || 
        new_state == "busy" || 
        @last_status_time + 60 < Time.now
      @state = new_state
      send_status_message(new_state)
    end
  end

  def handle_message(msg)
    #pp msg
    set_state("busy")
    body = msg[0][:body]
    msg_id = msg[0][:id]

    work_id, n = body.split(/\|/)
    send_log_message "Processing: #{work_id} #{n}"

    start_time = Time.now
    @primes_generator = Primes.new
    primes = @primes_generator.primes(n.to_i)
    end_time = Time.now

    if primes
      @sqs.delete_message(@work_queue, msg_id)
      send_log_message "Processed: #{work_id} #{n} primes (#{primes.last}) in #{(end_time-start_time).round}"
    end
  end

  def message_loop
    res = @sqs.receive_messages(@work_queue)
    if res.nil? || res.length == 0
      #@log.puts "no messages"
      set_state("idle")
      sleep 5
    else
       handle_message(res)
    end
  end

  def shutdown
    @shutdown = true
    @primes_generator.shutdown if @primes_generator
  end

  def run
    while ! @shutdown
      message_loop
    end
  end

end

begin

  # Get credentials from user_data
  user_data = UserData.load

  # Set up a prime generator
  prime_generator = PrimeGenerator.new(user_data[:iid], UserData.keys, 
    "primes-work", "primes-status", log)

  # Catch interrupts
  Signal.trap("INT") do
    prime_generator.shutdown
  end

  # Run the prime generator.
  prime_generator.run
rescue 
  log.puts "error #{$!}"
  pp "#{$@}"
  exit 1
end
