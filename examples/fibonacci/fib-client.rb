#!/usr/bin/ruby
$:.unshift File.join(File.dirname(__FILE__))

require 'net/telnet'

#
#  Connects to fib client on the given host:port.
#  Requests a new fib valie once a second.
class FibClient
  # Create a new FibClient on the given host and port.
  def initialize(host, port)
    @client = Net::Telnet::new('Host' => host,
       'Port' => port,
       'Telnetmode' => false)
    @shutdown = false
  end

  # Read from the server up to a newline, and return the 
  # result (minus the newline).
  def next_fib
    result = ''
    @client.cmd("") do |str|
      if str.nil?
        # This happens if serfver stops
        shutdown
	break
      end
      result << str
      break if result.include? "\n"
    end
    result.chomp
  end

  # Shuts down the client.
  def shutdown
    @shutdown = true
  end

  # Gets and displays a new fibonacci number once a second.
  def run
    until @shutdown do
      puts next_fib
      sleep 1
    end
  end
end

