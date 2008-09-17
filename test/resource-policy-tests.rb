$:.unshift(File.join(ENV['AWS_HOME'], "app"))
require 'test/unit'
require 'MockAWS/clock'
require 'logger_factory'
require 'configuration'
require 'pool_configuration'
require 'policy_limit'
require 'aws_context'
require 'pp'

# test the PolicyResource class.
class ResourcePolicyTests < Test::Unit::TestCase
  def setup
    LoggerFactory.setup("/tmp/test.out")
    logf = LoggerFactory.create(:file)
    Clock.set(0)
    config_files = ['aws-config.ini', 'default-config.ini', 'test-config.ini']
    Cloudmaster::Configuration.setup_config_files(config_files)
    tc = Cloudmaster::Configuration.new([], [:fib])
    cfg = Cloudmaster::PoolConfiguration.new(tc.aws, tc.default, tc.pools[0])
    reporter = Cloudmaster::Reporter.setup(cfg[:name], logf)
    cfg[:ami_id] = "ami-08856161"
    @cfg = cfg
    AwsContext.setup(:mock, logf)
    @pool = Cloudmaster::InstancePool.new(reporter, @cfg)
    @nq = @cfg[:work_queue] = Cloudmaster::NamedQueue.new(@cfg[:work_queue_name])
    @rp = Cloudmaster::PolicyFactory.create(@cfg[:policy], reporter, @cfg, @pool)
    @lp = Cloudmaster::PolicyLimit.new(reporter, @cfg, @pool)
    queue_name = 'fib-work'
    @queue = AwsContext.instance.sqs.list_queues(queue_name).first
    @message = 'this is a test'
  end

  def send_work(n)
    n.times { AwsContext.instance.sqs.send_message(@queue, @message)}
    @nq.read_queue_depth
  end

  def test_idle
    assert_equal(0, @rp.adjust)
  end

  def test_start_first
    send_work(1)
    assert_equal(1, @rp.adjust)
    # given load factor=10 and target upper load=0.75
    # it goes to 2 between 7 and 8
    send_work(7)
    assert_equal(1, @rp.adjust)
    send_work(8)
    assert_equal(2, @rp.adjust)
  end

  def test_start_more
    # two instances, both busy
    @pool.start_n_instances(2)
    @pool.each {|i| i.activate}
    @pool.each {|i| i.load_estimate = 0.8}
    # need to start another -- a little over threshold
    assert_equal(1, @rp.adjust)
    # two instances, not busy, don't start another
    @pool.each {|i| i.load_estimate = 0.5}
    assert_equal(0, @rp.adjust)
    # make sure limit honored (start_limit == 1)
    @pool.each {|i| i.load_estimate = 0.75}
    assert_equal(0, @lp.adjust(@rp.adjust))
    # only stops 1 due to limmit (stop_limit == 1)
    @pool.each {|i| i.load_estimate = 0}
    assert_equal(-2, @rp.adjust)
    assert_equal(-1, @lp.adjust(@rp.adjust))
    # now it can stop two    
    @cfg[:stop_limit] = 2
    assert_equal(-2, @rp.adjust)
  end

  def test_shut_down_n_instances
    # activate two
    @pool.start_n_instances(2)
    @pool.each {|i| i.activate}
    # shut down one
    @rp.shut_down_n_instances(1)
    sd = @pool.inject(0) {|sum, i| sum + (i.state == :shut_down ? 1 : 0)}
    # see that one is shut down
    assert_equal(1, sd)
  end

  def test_shut_down_instances
    # activate two
    @pool.start_n_instances(2)
    # shut down one
    @pool.each {|i| i.activate}
    @rp.shut_down_instances([@pool.first])
    sd = @pool.inject(0) {|sum, i| sum + (i.state == :shut_down ? 1 : 0)}
    # see that one is shut down
    assert_equal(1, sd)
  end

  def test_active_shut_down_instances
    # activate two
    @pool.start_n_instances(2)
    @pool.each {|i| i.activate}
    # shut down one
    @rp.shut_down_instances([@pool.first])
    @rp.activate_shut_down_instances(1)
    active = @pool.inject(0) {|sum, i| sum + (i.state == :active ? 1 : 0)}
    # see that both are active
    assert_equal(2, active)
  end

  def test_cleanup_shut_down_instances
    # activate two
    @pool.start_n_instances(2)
    Clock.set(3605)
    # shut down one
    @pool.each {|i| i.activate}
    @rp.shut_down_instances([@pool.first])
    sd = @pool.inject(0) {|sum, i| sum + (i.state == :shut_down ? 1 : 0)}
    @rp.clean_up_shut_down_instances
    sd = @pool.inject(0) {|sum, i| sum + (i.state == :shut_down ? 1 : 0)}
    # see that none is shut down
    assert_equal(0, sd)
    active = @pool.inject(0) {|sum, i| sum + (i.state == :active ? 1 : 0)}
    # see that one is active
    assert_equal(1, active)
  end
end