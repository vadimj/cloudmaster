$:.unshift(File.join(ENV['AWS_HOME'], "app"))
require 'test/unit'
require 'MockAWS/clock'
require 'logger_factory'
require 'configuration'
require 'pool_configuration'
require 'aws_context'
require 'pp'

# Test that the standard policy classes can be created, and have the
# right class names.  This tests the dynamic loading of the policy code.
# It tests the job and resource policies, as well as the fixed policy.
class FixedPolicyTests < Test::Unit::TestCase
  def startup(pool)
    LoggerFactory.setup("/tmp/test.out")
    logf = LoggerFactory.create(:file)
    config_files = ['aws-config.ini', 'default-config.ini', 'test-config.ini']
    Cloudmaster::Configuration.setup_config_files(config_files)
    tc = Cloudmaster::Configuration.new([], [pool])
    cfg = Cloudmaster::PoolConfiguration.new(tc.aws, tc.default, tc.pools[0])
    reporter = Cloudmaster::Reporter.setup(cfg[:name], logf)
    cfg[:ami_id] = "ami-08856161"
    @cfg = cfg
    AwsContext.setup(:mock, logf)
    @pool = Cloudmaster::InstancePool.new(reporter, @cfg)
    @policy = Cloudmaster::PolicyFactory.create(@cfg[:policy], reporter, @cfg, @pool)
  end

  def test_primes
    startup(:primes)
    assert_equal(Cloudmaster::PolicyJob, @policy.class)
  end

  def test_fib
    startup(:fib)
    assert_equal(Cloudmaster::PolicyResource, @policy.class)
  end

  def test_fixed_policy
    startup(:fixed)
    assert_equal(Cloudmaster::PolicyFixed, @policy.class)
  end

  def test_bad_policy
    assert_raise(LoadError) do
      startup(:bad)
      Cloudmaster::PolicyDefault
    end
  end
end
