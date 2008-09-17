$:.unshift(File.join(ENV['AWS_HOME'], "app"))
require 'test/unit'
require 'stringio'
require 'rexml/document'
require 'time'
require 'MockAWS/clock'
require 'logger_factory'
require 'configuration'
require 'pool_configuration'
require 'pool_runner'
require 'aws_context'
require 'pp'

# Test the Cloudmaster class.
class CloudmasterTests < Test::Unit::TestCase
  def setup
    # Append output to string
    LoggerFactory.setup("/tmp/test.out")
    logf = LoggerFactory.create(:file)
    AwsContext.setup(:mock, logf)
    @ec2 = AwsContext.instance.ec2
    @sqs = AwsContext.instance.sqs
    Clock.reset
    @ps = nil
  end

  def teardown
    @ps.shutdown if @ps
  end

  def configure(opts)
    config_files = ['aws-config.ini', 'default-config.ini', 'test-config.ini']
    Cloudmaster::Configuration.setup_config_files(config_files)
    @cfg = Cloudmaster::Configuration.new([], opts)
  end

  def startup
    @ps = Cloudmaster::PoolRunner.new(@cfg)
  end

  # Send message to primes work queue.
  def send_work
    url = "http://queue.amazonaws.com/A13T024T56MRDC/primes-work-test"
    body = "1|3649"
    @sqs.send_message(url, body)
  end

  # Send message to fib work queue.
  def send_fib_work
    url = "http://queue.amazonaws.com/A13T024T56MRDC/fib-work-test"
    body = "test"
    @sqs.send_message(url, body)
  end

  # Receive a message from primes work queue.
  def rec_message
    url = "http://queue.amazonaws.com/A13T024T56MRDC/primes-work-test"
    @sqs.receive_messages(url)
  end

  # Delete a message from primes work queue, given its id.
  def del_message(id)
    url = "http://queue.amazonaws.com/A13T024T56MRDC/primes-work-test"
    @sqs.delete_message(url, id)
  end

  # Both receive and delete message from primes work queue.
  def consume_message
    msg = rec_message
    del_message(msg.first[:id])
  end

  # Send a message on the primes status queue.
  def send_status_message(inst, load = 1)
    url = "http://queue.amazonaws.com/A13T024T56MRDC/primes-status-test"
    body = YAML.dump({ :type => 'status',
      :instance_id => inst, 
      :state => 'active',
      :load_estimate => load,
      :timestamp => Clock.now})
    @sqs.send_message(url, body)
  end

  # Send a message on the primes status queue.
  def send_status_message_lifeguard(inst, load = 1)
    url = "http://queue.amazonaws.com/A13T024T56MRDC/primes-status-test"
    doc = REXML::Document.new
    is = doc.add_element 'InstanceStatus'
    iid = is.add_element 'InstanceId'
    iid.add_text inst
    st = is.add_element 'State'
    st.add_text 'busy'
    li = is.add_element 'LastInterval'
    li.add_text 'PT60S'
    ts = is.add_element 'Timestamp'
#    ts.add_text(Time.now.xmlschema)
    ts.add_text(Clock.now.time.to_s)
    body = String.new
    doc.write(body, 2)
    @sqs.send_message(url, body)
  end

  # Send a message on the fib status queue.
  def send_fib_status_message(inst, load = 1)
    url = "http://queue.amazonaws.com/A13T024T56MRDC/fib-status-test"
    body = YAML.dump({ :type => 'status',
      :instance_id => inst, 
      :state => 'active',
      :load_estimate => load,
      :timestamp => Clock.now})
    @sqs.send_message(url, body)
  end

  # Send a log message on the primes status queue.
  def send_log_message(msg)
    url = "http://queue.amazonaws.com/A13T024T56MRDC/primes-status-test"
    msg = { :type => 'log', 
      :instance_id => 'iid-fake', 
      :message => msg,
      :timestamp => Clock.now}
    @sqs.send_message(url, YAML.dump(msg))
  end

  # verify nothing created when queue empty
  def test_idle
    configure([:primes]); startup
    @ps.run(Clock.at(65))
    assert_equal(0, @ec2.count)
  end

  # verify create when queue occupied
  def test_create_by_queue
    configure([:primes]); startup
    send_work
    @ps.run(Clock.at(65))
    assert_equal(1, @ec2.count)
  end

  # verify audit picks up existing instances
  def test_discover
    configure([:primes]); startup
    ami_id = @ec2.valid_ami_id
    opts = {}
    @ec2.run_instances(ami_id, 1, 1, opts)  
    @ps.run(Clock.at(65))
    assert_equal(1,  @ec2.count)
  end

  # verify audit detects missng instances
  def test_missing
    configure([:primes]); startup
    @ps = Cloudmaster::PoolRunner.new(@cfg)
  end

  # verify  minimum insances
  def test_minimum
    configure([:primes])
    @cfg.pools[0][:minimum_number_of_instances] = 1
    startup
    @ps.run(Clock.at(65))
    assert_equal(1, @ec2.count)
  end

  # verify creation to max
  def test_maximum
    configure([:primes]); startup
    send_work
    @ps.run(Clock.at(65))
    assert_equal(1, @ec2.count)
    # only three -- no increase
    send_work; send_work
    @ps.run(Clock.at(125))
    assert_equal(1, @ec2.count)
    # now four -- increase
    send_work
    @ps.run(Clock.at(185))
    assert_equal(2, @ec2.count)
    # still four queued -- ensure total does not increase
    @ps.run(Clock.at(245))
    assert_equal(2, @ec2.count)
  end

  # verify handling log message
  def test_log_message
    configure([:primes]); startup
    send_log_message('this is a test')
    @ps.run(Clock.at(5))
    logger = @ps.pool_managers[0].logger
    assert_match("0 primes iid-fake this is a test", logger.string)
  end

  # verify handling status message
  def test_status_message
    configure([:primes]); startup
    send_work
    @ps.run(Clock.at(65))
    @ps.run(Clock.at(125))
    assert_equal(:startup, @ps.pool_managers[0].instances.first.state)
    send_status_message('i-1')
    @ps.run(Clock.at(185))
    assert_equal(:active, @ps.pool_managers[0].instances.first.state)
  end

  # verify update public dns 
  def test_public_dns
    configure([:primes]); startup
    send_work
    @ps.run(Clock.at(65))
    assert_equal(nil, @ps.pool_managers[0].instances.first.public_dns)
    id = @ec2.first_id
    assert_equal("", @ec2.get_public_dns(id))
    @ec2.set_public_dns(id, "dns-xx")
    @ps.run(Clock.at(75))
    assert_equal("dns-xx", @ec2.get_public_dns(id))
    assert_equal("dns-xx", @ps.pool_managers[0].instances.first.public_dns)
  end

  # verify job policy increase
  def test_job_increase
    configure([:primes]); startup
    send_work; send_work
    @ps.run(Clock.at(65))
    assert_equal(1, @ec2.count)
    # let it run longer -- shouled create another
    send_work; send_work
    @ps.run(Clock.at(125))
    assert_equal(2, @ec2.count)
  end

  # verify job policy no change
  def test_job_same
    configure([:primes]); startup
    send_work
    @ps.run(Clock.at(65))
    assert_equal(1, @ec2.count)
    msg = rec_message
    del_message(msg.first[:id])
    # let it run longer -- shouled not create another
    @ps.run(Clock.at(125))
    assert_equal(1, @ec2.count)
  end

  # verify job policy decrease
  def test_job_decrease
    configure([:primes]); startup
    4.times { send_work }
    @ps.run(Clock.at(65))
    assert_equal(2, @ec2.count)
    4.times { consume_message }
    send_status_message('i-1', 0)
    send_status_message('i-2', 0)
    # run to next policy evaluation
    @ps.run(Clock.at(400))
    assert_equal(0, @ec2.count)
  end

  # verify resource policy increase (many cases)
  def test_resource_increase
    configure([:fib]); startup
    send_fib_work
    @ps.run(Clock.at(65))
    assert_equal(1, @ec2.count)
  end

  # verify resource policy no change
  def test_resource_same
    configure([:fib]); startup
    send_fib_work
    @ps.run(Clock.at(65))
    assert_equal(1, @ec2.count)
    @ps.pool_managers[0].instances.first.state = :active
    @ps.pool_managers[0].instances.first.load_estimate = 0.5
    @ps.run(Clock.at(400))
    assert_equal(1, @ec2.count)
   end

  # verify resource policy decrease
  def test_resource_decrease
    configure([:fib]); startup
    send_fib_work
    @ps.run(Clock.at(65))
    assert_equal(1, @ec2.count)
    send_fib_status_message('i-1', 0.1)
    @ps.run(Clock.at(400))
    assert_equal(1, @ec2.count)
    send_fib_status_message('i-1', 0)
    @ps.run(Clock.at(465))
    assert_equal(0, @ec2.count)
  end

  # verify write active set
  def test_active_set
    configure([:primes]); startup
    # let it run
    # read from S3 and test if active-set is there and has right value
    send_work
    @ps.run(Clock.at(125))
    val = AwsContext.instance.s3.get_object('chayden', 'active-set/primes-instances-test')
    assert_equal("--- []\n\n", val)
  end

  # verify hung instances cleaned up
  def test_hang
    configure([:primes]); startup
    #let it run for a long time, until min lifetime and hang time
    # see that it stops the instance
    send_work
    @ps.run(Clock.at(65))
    assert_equal(1, @ec2.count)
    @ps.run(Clock.at(700))
    assert_equal(0, @ec2.count)
  end

  # verify handling status message
  def test_status_message_lifeguard
    configure([:primes]);
    @cfg.pools[0][:status_parser] = 'lifeguard'
    startup
    send_work
    @ps.run(Clock.at(65))
    @ps.run(Clock.at(125))
    assert_equal(:startup, @ps.pool_managers[0].instances.first.state)
    send_status_message_lifeguard('i-1')
    @ps.run(Clock.at(185))
    assert_equal(:active, @ps.pool_managers[0].instances.first.state)
  end

end

