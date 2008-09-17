$:.unshift(File.join(ENV['AWS_HOME'], "app"))
require 'test/unit'
require 'MockAWS/clock'
require 'logger_factory'
require 'aws_context'
require 'named_queue'
require 'pp'

# test the NamedQueue implementation.
class NamedQueueTests < Test::Unit::TestCase
  def setup
    LoggerFactory.setup("/tmp/test.out")
    logf = LoggerFactory.create(:file)
    @sqs = AwsContext.setup(:mock, logf).sqs
  end

  def test_none
    nq = Cloudmaster::NamedQueue.new('xxx')
    assert(true)
  end

  def test_one
    nq = Cloudmaster::NamedQueue.new('primes-work')
    assert(true)
  end

  def test_many
    assert_raise(RuntimeError) do
      nq = Cloudmaster::NamedQueue.new('primes')
    end
  end

  def test_read_message
    queue_name = 'primes-work'
    queue = @sqs.list_queues(queue_name).first
    nq = Cloudmaster::NamedQueue.new(queue_name)
    msgs = nq.read_messages(1)
    assert_equal([], msgs)
    message = 'this is a test'
    @sqs.send_message(queue, message)
    # we can read
    msgs = nq.read_messages(1)
    assert_equal(1, msgs.size)
    assert_equal(message, msgs.first[:body])    
    msgs = nq.read_messages(1)
    assert_equal(1, msgs.size)
    assert_equal(message, msgs.first[:body])    
    nq.delete_message(msgs.first[:id])
    msgs = nq.read_messages(1)
    assert_equal(0, msgs.size)
  end

  def test_delete_message
    queue_name = 'primes-work'
    queue = @sqs.list_queues(queue_name).first
    nq = Cloudmaster::NamedQueue.new(queue_name)
    message = 'this is a test'
    @sqs.send_message(queue, message)
    msgs = nq.read_messages(1)
    assert_equal(1, msgs.size)
    assert_equal(message, msgs.first[:body])    
    msgs = nq.read_messages(1)
    nq.delete_message(msgs.first[:id])
    msgs = nq.read_messages(1)
    assert_equal(0, msgs.size)
  end

  def test_read_queue_depth
    queue_name = 'primes-work'
    queue = @sqs.list_queues(queue_name).first
    nq = Cloudmaster::NamedQueue.new(queue_name)
    message = 'this is a test'
    @sqs.send_message(queue, message)
    @sqs.send_message(queue, message)
    @sqs.send_message(queue, message)
    assert_equal(3, nq.read_queue_depth)
  end

 def test_empty_queue
    queue_name = 'primes-work'
    queue = @sqs.list_queues(queue_name).first
    nq = Cloudmaster::NamedQueue.new(queue_name)
    message = 'this is a test'
    @sqs.send_message(queue, message)
    @sqs.send_message(queue, message)
    @sqs.send_message(queue, message)
    nq.empty_queue
    assert_equal(0, nq.read_queue_depth)
  end
end