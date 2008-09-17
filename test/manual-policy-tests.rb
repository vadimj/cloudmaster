$:.unshift(File.join(ENV['AWS_HOME'], "app"))
require 'test/unit'
require 'MockAWS/clock'
require 'logger_factory'
require 'configuration'
require 'pool_configuration'
require 'policy_limit'
require 'aws_context'
require 'pp'

# Test the ManualPolicy class.
# Make sure it adjusts the number of instances appropriately in all cases.
class ManualPolicyTests < Test::Unit::TestCase
  def setup
    LoggerFactory.setup("/tmp/test.out")
    logf = LoggerFactory.create(:file)
    Clock.set(0)
    config_files = ['aws-config.ini', 'default-config.ini', 'test-config.ini']
    Cloudmaster::Configuration.setup_config_files(config_files)
    tc = Cloudmaster::Configuration.new([], [:manual])
    cfg = Cloudmaster::PoolConfiguration.new(tc.aws, tc.default, tc.pools[0])
    reporter = Cloudmaster::Reporter.setup(cfg[:name], logf)
    cfg[:ami_id] = "ami-08856161"
    @cfg = cfg
    AwsContext.setup(:mock, logf)
    @pool = Cloudmaster::InstancePool.new(reporter, @cfg)
    @mq = Cloudmaster::NamedQueue.new(@cfg[:manual_queue_name])
    @mp = Cloudmaster::PolicyFactory.create(@cfg[:policy], reporter, @cfg, @pool)
    @lp = Cloudmaster::PolicyLimit.new(reporter, @cfg, @pool)
    queue_name = 'manual-manual'
    @queue = AwsContext.instance.sqs.list_queues(queue_name).first
  end

  def send_work(n, adjust)
    message = YAML.dump({ :adjust => adjust})
    n.times { AwsContext.instance.sqs.send_message(@queue, message)}
  end

  def test_idle
    assert_equal(0, @mp.adjust)
  end

  def test_adjust_up
    send_work(1, 1)
    assert_equal(1, @mp.adjust)
    send_work(1, 2)
    assert_equal(2, @mp.adjust)
    send_work(2, 1)
    assert_equal(2, @mp.adjust)
    send_work(2, 1)
    send_work(1, -1)
    assert_equal(1, @mp.adjust)
  end

  def test_adjust_down
    send_work(1, -1)
    assert_equal(-1, @mp.adjust)
    send_work(1, -2)
    assert_equal(-2, @mp.adjust)
    send_work(2, -1)
    assert_equal(-2, @mp.adjust)
  end
end