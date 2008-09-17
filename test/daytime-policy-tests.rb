$:.unshift(File.join(ENV['AWS_HOME'], "app"))
require 'test/unit'
require 'logger_factory'
require 'MockAWS/clock'
require 'configuration'
require 'pool_configuration'
require 'aws_context'
require 'pp'

# Test the DaytimePolicy class.
# This class is an example of adding an additional policy to the system.
class DaytimePolicyTests < Test::Unit::TestCase
  def setup
    LoggerFactory.setup("/tmp/test.out")
    logf = LoggerFactory.create(:file)
    config_files = ['aws-config.ini', 'default-config.ini', 'test-config.ini']
    Cloudmaster::Configuration.setup_config_files(config_files)
    tc = Cloudmaster::Configuration.new([], [:daytime])
    cfg = Cloudmaster::PoolConfiguration.new(tc.aws, tc.default, tc.pools[0])
    reporter = Cloudmaster::Reporter.setup(cfg[:name], logf)
    cfg[:ami_id] = "ami-08856161"
    @cfg = cfg
    AwsContext.setup(:mock, logf)
    @pool = Cloudmaster::InstancePool.new(reporter, @cfg)
    @policy = Cloudmaster::PolicyFactory.create(@cfg[:policy], reporter, @cfg, @pool)
    Clock.reset
  end

  def test_daytime_load
    assert_equal(Cloudmaster::PolicyDaytime, @policy.class)
  end

  def test_nighttime
    assert_equal(0, @policy.adjust)
  end

  def test_daytime_additional
    Clock.set(11 * 3600)
    assert_equal(1, @policy.adjust)
  end

  def test_daytime_max
    @pool.start_n_instances(3)
    Clock.set(11 * 3600)
    assert_equal(0, @policy.adjust)
  end
end