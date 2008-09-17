$:.unshift(File.join(ENV['AWS_HOME'], "app"))
require 'pp'
require 'test/unit'
require 'MockAWS/clock'
require 'logger_factory'
require 'configuration'
require 'pool_configuration'
require 'aws_context'
require 'reporter'

# Test the ConfigInfo class.  
# This also test InifileConfig
class ConfigInfoTests < Test::Unit::TestCase
  def setup
    LoggerFactory.setup("/tmp/test.out")
    logf = LoggerFactory.create(:file)
    @sqs = AwsContext.setup(:mock, logf).sqs
    config_files = ['aws-config.ini', 'default-config.ini', 'test-config.ini']
    Cloudmaster::Configuration.setup_config_files(config_files)
    tc = Cloudmaster::Configuration.new([], [:primes])
    cfg = Cloudmaster::PoolConfiguration.new(tc.aws, tc.default, tc.pools[0])
    reporter = Cloudmaster::Reporter.setup(cfg[:name], logf)
    cfg[:ami_id] = "ami-08856161"
    @cfg = cfg
  end

  def test_get
    assert_equal(nil, @cfg.get(:xxx))
    assert_equal(:primes, @cfg.get(:name))
    assert_equal(20, @cfg.get(:receive_count).to_i)
  end

  def test_fetch
    assert_equal(:primes, @cfg[:name])
    assert_equal(20, @cfg[:receive_count].to_i)
    assert_raise(RuntimeError) do
      @cfg[:xxx]
    end
  end

  def test_store
    assert_equal(:primes, @cfg[:name])
    @cfg[:name] = "new-name"
    assert_equal('new-name', @cfg[:name])
    assert_equal(20, @cfg[:receive_count].to_i)
    @cfg[:receive_count] = 30
    assert_equal(30, @cfg[:receive_count])
    assert_raise(RuntimeError) do
      @cfg[:xxx]
    end
    @cfg[:xxx] = 5
    assert_equal(5, @cfg[:xxx])      
  end

  def test_groups
    assert_equal('["a", "b"]', @cfg[:security_groups])
  end

  def test_user_data
    assert_equal(1234, @cfg[:user_data][:newkey])
  end
end