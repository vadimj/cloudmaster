$:.unshift(File.join(ENV['AWS_HOME'], "app"))
require 'test/unit'
require 'MockAWS/clock'
require 'logger_factory'
require 'configuration'
require 'pool_configuration'
require 'pp'

# Test the Instance class.
class InstanceTests < Test::Unit::TestCase
  def setup
    Clock.set(0)
    config_files = ['aws-config.ini', 'default-config.ini', 'test-config.ini']
    Cloudmaster::Configuration.setup_config_files(config_files)
    tc = Cloudmaster::Configuration.new([''], [:primes])
    cfg = Cloudmaster::PoolConfiguration.new(tc.aws, tc.default, tc.pools[0])
    @inst = Cloudmaster::Instance.new('iid-fake', '', cfg)
  end

  def state_msg(t, st)
    {:timestamp => Clock.at(t), :state => st}
  end

  def test_update_status
    # verify more recent messages are stored, but old ones skipped    
    @inst.update_status(state_msg(1, "active1"))
    assert_equal(1, @inst.timestamp.time)
    assert_equal(:active1, @inst.state)
    @inst.update_status(state_msg(2, "active2"))
    assert_equal(2, @inst.timestamp.time)
    assert_equal(:active2, @inst.state)
    @inst.update_status(state_msg(1, "active1"))
    assert_equal(:active2, @inst.state)    
  end

  def test_time_time_since_status
    assert_equal(0, @inst.time_since_status)
    Clock.set(5)
    assert_equal(5, @inst.time_since_status)
    @inst.update_status(state_msg(10, "active"))
    assert_equal(0, @inst.time_since_status)
  end

  def test_time_since_state_change
    assert_equal(0, @inst.time_since_state_change)
    Clock.set(5)
    assert_equal(5, @inst.time_since_state_change)
    @inst.update_status(state_msg(10, "active"))
    assert_equal(0, @inst.time_since_state_change)
  end

  def test_time_since_startup
    assert_equal(0, @inst.time_since_state_change)
    Clock.set(5)
    assert_equal(5, @inst.time_since_state_change)
    Clock.set(10)
    assert_equal(10, @inst.time_since_state_change)
  end

  def test_report
    @inst.report
    assert(true)
  end

  def test_minimum_lifetime_elapsed
    assert(! @inst.minimum_lifetime_elapsed?)    
    Clock.set(3600)
    assert(@inst.minimum_lifetime_elapsed?)    
  end

  def test_minimum_lifetime_elapsed
    assert(! @inst.watchdog_time_elapsed?)    
    Clock.set(3600)
    assert(@inst.watchdog_time_elapsed?)    
  end

  def test_shutdown
    assert_equal(:startup, @inst.state)
    @inst.update_status(state_msg(10, "active"))
    assert_equal(:active, @inst.state)
    Clock.set(5)
    @inst.shutdown    
    assert_equal(:shut_down, @inst.state)
    assert_equal(5, @inst.state_change_time.time)
  end

  def test_activate
    Clock.set(5)
    @inst.shutdown
    assert_equal(:shut_down, @inst.state)
    @inst.activate
    assert_equal(:active, @inst.state)
    assert_equal(5, @inst.state_change_time.time)
  end

  def test_one
  end
end