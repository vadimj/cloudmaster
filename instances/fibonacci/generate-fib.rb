#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__))
$:.unshift File.join(ENV['HOME'], 'lib')
require 'aws_context'
require 'user_data'
require 'clock'
require 'periodic'
require 'pp'
require 'open-uri'
require 'yaml'
require 'gserver'

# Compute successive fibonacci numbers
class Fibonacci

  def initialize
    @f1, @f2 = 1, 1
  end

  def next
    @f1, @f2 = @f2, @f1 + @f2
    @f1
  end
end

class FibServer < GServer
  def initialize(port=20808, host=GServer::DEFAULT_HOST)
    @clients = []
    @max_clients = 10
    super(port, host, 1000, $stderr, true)
  end

  def load
    @clients.size.to_f/@max_clients
  end

  def serve(sock)
    begin
      @clients <<sock
      fib = Fibonacci.new
      until sock.eof? do
        break if sock.gets.chomp == 'quit'
	next_value = fib.next
        sock.puts(next_value)
      end
    ensure
      @clients.delete(sock)
    end
  end
end


#  Manages generation of fibonacci numbers.
#  Clients connect, and they receive an unending sequence of fibonacci numbers.
#  Once a minute, a status report is sent to cloudmaster.

class FibonacciGenerator
  # initialize queues from names
  def initialize(instance_id, keys, 
      status_queue_name, port, host)
    @instance_id = instance_id
    @sqs = AwsContext.instance.sqs(*keys)
    @fib_server = FibServer.new(port, host)
    @state = "none"

    begin
      @status_queue = @sqs.list_queues(status_queue_name).first
      if @status_queue.nil?
        puts "error #{$!} #{status_queue_name}"
        raise "no status queue"
      end
    rescue
      puts "error #{$!}"
      raise "cannot list queues"
    end
  end

  def send_status_message(load)
    msg = { :type => 'status',
      :instance_id => @instance_id, 
      :state => 'active',
      :load_estimate => load,
      :timestamp => Time.now}
    @sqs.send_message(@status_queue, YAML.dump(msg))
  end

  def send_log_message(message)
    puts message
    msg = { :type => 'log', 
      :instance_id => @instance_id, 
      :message => message,
      :timestamp => Time.now}
    @sqs.send_message(@status_queue, YAML.dump(msg))
  end

  def send_load
    estimated_load = @fib_server.load
    puts "Load: #{estimated_load}"
    send_status_message(estimated_load)
  end

  def shutdown
    @fib_server.stop
  end

  def run
    @fib_server.start(-1)
    @fib_server.join
  end
end

case ARGV.size
when 0
  host = "0.0.0.0"
  port = 20808
when 1
  host = "0.0.0.0"
  port = 20808
when 2
  host = ARGV[1]
  port = 20808
when 3
  host = ARGV[1]
  port = ARGV[2]
end

begin
  # Get credentials from user_data
  user_data = UserData.load

  shutdown = false

  # Set up a fibonacci generator
  fib_generator = FibonacciGenerator.new(user_data[:iid], UserData.keys, 
    "fib-status", port, host)

  # Catch interrupts
  Signal.trap("INT") do
    fib_generator.shutdown
    shutdown = true
  end

  # start another thread to report the load
  reporter = Thread.new do
    send_period = Periodic.new(60)    # send once a minute
    while !shutdown
      send_period.check { fib_generator.send_load }
      sleep 5
    end
  end
  
  # Run the fibonacci generator.
  fib_generator.run

  reporter.join

rescue 
  puts "error #{$!}"
  pp "#{$@}"
  exit 1
end
