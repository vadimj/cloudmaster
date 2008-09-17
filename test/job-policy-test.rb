$:.unshift(File.join(ENV['AWS_HOME'], "app"))
require 'test/unit'
require 'MockAWS/clock'
require 'logger_factory'
require 'configuration'
require 'pool_configuration'
require 'policy_limit'
require 'aws_context'
require 'pp'

# Test the JobPolicy class.
# Make sure it adjusts the number of instances appropriately in all cases.
class JobPolicyTests < Test::Unit::TestCase
  def setup
    LoggerFactory.setup("/tmp/test.out")
    logf = LoggerFactory.create(:file)
    Clock.set(0)
    config_files = ['aws-config.ini', 'default-config.ini', 'test-config.ini']
    Cloudmaster::Configuration.setup_config_files(config_files)
    tc = Cloudmaster::Configuration.new([''], [:primes])
    cfg = Cloudmaster::PoolConfiguration.new(tc.aws, tc.default, tc.pools[0])
    reporter = Cloudmaster::Reporter.setup(cfg[:name], logf)
    cfg[:ami_id] = "ami-08856161"
    @cfg = cfg
    AwsContext.setup(:mock, logf)
    @pool = Cloudmaster::InstancePool.new(reporter, @cfg)
    @nq = @cfg[:work_queue] = Cloudmaster::NamedQueue.new(@cfg[:work_queue_name])
    @jp = Cloudmaster::PolicyFactory.create(@cfg[:policy], reporter, @cfg, @pool)
    @lp = Cloudmaster::PolicyLimit.new(reporter, @cfg, @pool)
    queue_name = 'primes-work'
    @queue = AwsContext.instance.sqs.list_queues(queue_name).first
    @message = 'this is a test'
  end

  def send_work(n)
    n.times { AwsContext.instance.sqs.send_message(@queue, @message)}
    @nq.read_queue_depth
  end

  def test_idle
    assert_equal(0, @jp.adjust)
  end

  def test_start_more
    send_work(1)
    # with queue depth 1 ==> 1
    assert_equal(1, @jp.adjust)
    # with queue depth 2 ==> 1
    send_work(1)
    assert_equal(1, @jp.adjust)
    # with queue depth 4 ==> 2
    send_work(1)
    send_work(1)
    assert_equal(2, @jp.adjust)
    # with queue depth 6 ==> 3
    send_work(1)
    send_work(1)
    assert_equal(3, @jp.adjust)
    # with queue depth 6 ==> 2 (start_limit == 2)
    assert_equal(2, @lp.adjust(@jp.adjust))

    # now start 1
    @pool.start_n_instances(1)
    # depth is 6
    assert_equal(2, @jp.adjust)
    # depth is 6, but can only start 1 (max limit == 2)
    assert_equal(1, @lp.adjust(@jp.adjust))
  end

  def test_no_change
    # there is work aut we are at max_limit
    send_work(1)
    @pool.start_n_instances(2)
    assert_equal(0, @jp.adjust)
  end

  def test_stop_some
    @pool.start_n_instances(2)
    @pool.each {|i| i.activate}
    # it stops all
    assert_equal(-2, @jp.adjust)
    # if min_instances == 1, then it only stops 1
    @cfg[:minimum_number_of_instances] = 1
    assert_equal(-2, @jp.adjust)
    assert_equal(-1, @lp.adjust(@jp.adjust))
    # put it back at 0
    @cfg[:minimum_number_of_instances] = 0
    @pool.start_n_instances(1)
    @pool.each {|i| i.activate}
    # it would stop all three, except for limit (stop_limit = 2)
    assert_equal(-3, @jp.adjust)
    assert_equal(-2, @lp.adjust(@jp.adjust))
  end

end