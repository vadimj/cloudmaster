require 'pp'
require 'gserver'

# Computes successive fibonacci numbers.
# Each instance is independent -- it produces one stream of numbers.
class Fibonacci

  # Start the sequence.
  def initialize
    @f1, @f2 = 1, 1
  end

  # Return the next member of the sequence.
  def next
    @f1, @f2 = @f2, @f1+@f2
    @f1
  end
end

# The FibServer listens on a port for client connections.  
# Each client receives successive fibonacci numbers.
# A new number is delivered each time a newline is received.
# If the string "quit" is received, the server closes the connection.
# Each client gets their own connection, and their own seqence.
class FibServer < GServer
  def initialize(port=20808, host=GServer::DEFAULT_HOST)
    @clients = []
    super(port, host, Float::MAX, $stderr, true)
  end

  def serve(sock)
    begin
      @clients <<sock
      fib = Fibonacci.new
      until sock.eof? do
	 break if sock.gets.chomp == 'quit'
	 sock.puts(fib.next)
      end
    ensure
      @clients.delete(sock)
    end
  end
end

f=FibServer.new
f.start(-1)
f.join
