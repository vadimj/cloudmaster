$:.unshift(File.join(ENV['AWS_HOME'], "app"))
require 'test/unit'
require 'MockAWS/clock'
require 'logger_factory'
require 'configuration'
require 'pool_configuration'
require 'aws_context'
require 'pp'

# Test the InstancePool class.
class InstancePoolTests < Test::Unit::TestCase
  def setup
    LoggerFactory.setup("/tmp/test.out")
    logf = LoggerFactory.create(:file)
    Clock.set(0)
    config_files = ['aws-config.ini', 'default-config.ini', 'test-config.ini']
    Cloudmaster::Configuration.setup_config_files(config_files)
    tc = Cloudmaster::Configuration.new([''], [:primes])
    @cfg = Cloudmaster::PoolConfiguration.new(tc.aws, tc.default, tc.pools[0])
    reporter = Cloudmaster::Reporter.setup(@cfg[:name], logf)
    @cfg[:ami_id] = "ami-08856161"
    @ec2 = AwsContext.setup(:mock, logf).ec2
    @pool = Cloudmaster::InstancePool.new(reporter, @cfg)
  end

  def test_size
    assert_equal(0, @pool.size)
    @pool.add('iid-fake', '')
    assert_equal(1, @pool.size)
  end

  def test_enumerator
    count = 0
    @pool.each {|i| count += 1}
    assert_equal(0, count)
    assert_equal(0, @pool.size)
    @pool.add('iid-fake', '')
    count = 0
    @pool.each {|i| count += 1}
    assert_equal(1, count)
    assert_equal(1, @pool.size)
  end

  def test_delete
    assert_equal(0, @pool.size)
    inst = @pool.add('iid-fake', '')
    assert_equal(1, @pool.size)
    @pool.delete(inst)
    assert_equal(0, @pool.size)
  end

  def test_find_by_id
    assert_equal(nil, @pool.find_by_id('iid-fake'))
    inst = @pool.add('iid-fake', '')
    assert_equal(inst, @pool.find_by_id('iid-fake'))
  end

  def test_id_list
    assert_equal([], @pool.id_list)
    inst = @pool.add('iid-fake', '')
    assert_equal(['iid-fake'], @pool.id_list)
  end

  def test_less_than_minimum
    assert(!@pool.less_than_minimum?)
    @cfg[:minimum_number_of_instances] = 1
    assert(@pool.less_than_minimum?)
  end

  def test_greater_than_maximum
    assert(!@pool.greater_than_maximum?)
    inst = @pool.add('iid-fake1', '')
    inst = @pool.add('iid-fake2', '')
    inst = @pool.add('iid-fake3', '')
    assert_equal(3, @pool.size)
    assert(@pool.greater_than_maximum?)
  end

  def test_below_minimum_count
    assert_equal(0, @pool.below_minimum_count)
    @cfg[:minimum_number_of_instances] = 1
    assert_equal(1, @pool.below_minimum_count)
  end

  def test_above_maximum_count
    assert_equal(0, @pool.above_maximum_count)
    inst = @pool.add('iid-fake1', '')
    inst = @pool.add('iid-fake2', '')
    inst = @pool.add('iid-fake3', '')
    assert_equal(1, @pool.above_maximum_count)
  end

  def test_missing_public_dns_instances
    assert_equal([], @pool.missing_public_dns_instances)
    inst1 = @pool.add('iid-fake1', '')
    assert_equal([inst1], @pool.missing_public_dns_instances)
    inst2 = @pool.add('iid-fake2', 'present')
    assert_equal([inst1], @pool.missing_public_dns_instances)
  end

  def test_missing_public_dns_ids
    assert_equal([], @pool.missing_public_dns_ids)
    inst1 = @pool.add('iid-fake1', '')
    assert_equal(['iid-fake1'], @pool.missing_public_dns_ids)
    inst2 = @pool.add('iid-fake2', 'present')
    assert_equal(['iid-fake1'], @pool.missing_public_dns_ids)
  end

  def test_update_public_dns
    assert_equal([], @pool.missing_public_dns_ids)
    inst1 = @pool.add('iid-fake1', '')
    assert_equal(['iid-fake1'], @pool.missing_public_dns_ids)
    @pool.update_public_dns('iid-fake1', '')
    assert_equal(['iid-fake1'], @pool.missing_public_dns_ids)
    @pool.update_public_dns('iid-fake1', 'pub-dns-1')
    assert_equal([], @pool.missing_public_dns_ids)
  end

  def test_hung_instances
    inst1 = @pool.add('iid-fake1', '')
    assert_equal([], @pool.hung_instances)
    Clock.set(3600)
    assert_equal([inst1], @pool.hung_instances)
  end

  def test_active_instances
    inst1 = @pool.add('iid-fake1', '')
    assert_equal([], @pool.active_instances)
    msg = { :type => 'status',
      :instance_id => 'iid-fake2', 
      :state => 'active',
      :load_estimate => 1,
      :timestamp => Clock.at(5)}
    @pool.update_status(msg)
    assert_equal([], @pool.active_instances)
    msg = { :type => 'status',
      :instance_id => 'iid-fake1', 
      :state => 'active',
      :load_estimate => 1,
      :timestamp => Clock.at(5)}
    @pool.update_status(msg)
    assert_equal([inst1], @pool.active_instances)
  end

  def test_shut_down_instances
    assert_equal([], @pool.shut_down_instances)
    inst1 = @pool.add('iid-fake1', '')
    inst2 = @pool.add('iid-fake2', '')
    assert_equal([], @pool.shut_down_instances)
    @pool.shut_down([inst1])
    assert_equal([inst1], @pool.shut_down_instances)
  end

  def test_active_idle_instances
    inst1 = @pool.add('iid-fake1', '')
    inst2 = @pool.add('iid-fake2', '')
    msg = { :type => 'status',
      :instance_id => 'iid-fake1', 
      :state => 'active',
      :load_estimate => 0.5,
      :timestamp => Clock.at(10)}
    @pool.update_status(msg)
    msg = { :type => 'status',
      :instance_id => 'iid-fake2', 
      :state => 'active',
      :load_estimate => 0,
      :timestamp => Clock.at(10)}
    @pool.update_status(msg)
    # both are active, but only inst2 is idle
    assert_equal([inst2], @pool.active_idle_instances)
  end

  def test_shut_down_idle_instances
    inst1 = @pool.add('iid-fake1', '')
    inst2 = @pool.add('iid-fake2', '')
    msg = { :type => 'status',
      :instance_id => 'iid-fake1', 
      :state => 'active',
      :load_estimate => 1,
      :timestamp => Clock.at(10)}
    @pool.update_status(msg)
    @pool.shut_down([inst1, inst2])
    # both shut down, but only one idle
    assert_equal([inst2], @pool.shut_down_idle_instances)
  end

  def test_shut_down_timeout_instances
    inst1 = @pool.add('iid-fake1', '')
    inst2 = @pool.add('iid-fake2', '')
    @pool.shut_down([inst1])
    Clock.set(1800)
    @pool.shut_down([inst2])
    Clock.set(3595)
    assert_equal([], @pool.shut_down_timeout_instances)
    Clock.set(3605)
    # both shut down, but only inst1 has timed out
    assert_equal([inst1], @pool.shut_down_timeout_instances)
  end

  def test_state_change_time
    inst1 = @pool.add('iid-fake1', '')
    inst2 = @pool.add('iid-fake2', '')
    msg = { :type => 'status',
      :instance_id => 'iid-fake1', 
      :state => 'active',
      :load_estimate => 0.5,
      :timestamp => Clock.at(10)}
    @pool.update_status(msg)
    Clock.set(5)
    msg = { :type => 'status',
      :instance_id => 'iid-fake2', 
      :state => 'active',
      :load_estimate => 0,
      :timestamp => Clock.at(10)}
    @pool.update_status(msg)
    assert_equal(5, @pool.state_change_time.time)
  end

  def test_excess_capacity
    inst1 = @pool.add('iid-fake1', '')
    inst2 = @pool.add('iid-fake2', '')
    msg = { :type => 'status',
      :instance_id => 'iid-fake1', 
      :state => 'active',
      :load_estimate => 0.5,
      :timestamp => Clock.at(10)}
    @pool.update_status(msg)
    msg = { :type => 'status',
      :instance_id => 'iid-fake2', 
      :state => 'active',
      :load_estimate => 0.5,
      :timestamp => Clock.at(10)}
    @pool.update_status(msg)
    assert_equal(0.5, @pool.excess_capacity)
  end

  def test_total_load
    inst1 = @pool.add('iid-fake1', '')
    inst2 = @pool.add('iid-fake2', '')
    msg = { :type => 'status',
      :instance_id => 'iid-fake1', 
      :state => 'active',
      :load_estimate => 0.5,
      :timestamp => Clock.at(10)}
    @pool.update_status(msg)
    msg = { :type => 'status',
      :instance_id => 'iid-fake2', 
      :state => 'active',
      :load_estimate => 0.5,
      :timestamp => Clock.at(10)}
    @pool.update_status(msg)
    assert_equal(1, @pool.total_load)
  end

  def test_active_set
    inst1 = @pool.add('iid-fake1', 'dns-1')
    inst2 = @pool.add('iid-fake2', '')
    msg = { :type => 'status',
      :instance_id => 'iid-fake1', 
      :state => 'active',
      :load_estimate => 0.5,
      :timestamp => Clock.at(10)}
    @pool.update_status(msg)
    aset = YAML.load(@pool.active_set)
   assert_equal(1, aset.size)
   assert_equal('iid-fake1', aset[0][:id])
   assert_equal(0.5, aset[0][:load_estimate])
   assert_equal('dns-1', aset[0][:public_dns])
  end

  def test_sorted_by_lowest_load
    inst1 = @pool.add('iid-fake1', '')
    inst2 = @pool.add('iid-fake2', '')
    msg = { :type => 'status',
      :instance_id => 'iid-fake1', 
      :state => 'active',
      :load_estimate => 0.5,
      :timestamp => Clock.at(10)}
    @pool.update_status(msg)
    msg = { :type => 'status',
      :instance_id => 'iid-fake2', 
      :state => 'active',
      :load_estimate => 0.4,
      :timestamp => Clock.at(10)}
    @pool.update_status(msg)
    assert_equal([inst2, inst1], @pool.sorted_by_lowest_load)
  end
  
  def test_update_public_dns_all
    id1 = @ec2.run_instances('ami-08856161')[:instances][0][:id]
    inst1 = @pool.add(id1, '')
    id2 = @ec2.run_instances('ami-08856161')[:instances][0][:id]
    inst2 = @pool.add(id2, '')
    msg = { :type => 'status',
      :instance_id => id1, 
      :state => 'active',
      :load_estimate => 0.5,
      :timestamp => Clock.at(10)}
    @pool.update_status(msg)
    msg = { :type => 'status',
      :instance_id => id2, 
      :state => 'active',
      :load_estimate => 0.4,
      :timestamp => Clock.at(10)}
    @pool.update_status(msg)
    assert_equal([inst1, inst2], @pool.missing_public_dns_instances)
    @ec2.set_public_dns(id1, "dns-1")
    @pool.update_public_dns_all
    assert_equal([inst2], @pool.missing_public_dns_instances)
  end

  def test_our_running_instances
    assert_equal(0, @pool.our_running_instances.size)
    id1 = @ec2.run_instances('ami-08856161')[:instances][0][:id]
    id2 = @ec2.run_instances('ami-08856161')[:instances][0][:id]
    assert_equal(2, @pool.our_running_instances.size)
    @ec2.set_state(id1, "stopped")
    assert_equal(1, @pool.our_running_instances.size)
  end

  def test_audit_existing_instances_discover
    id1 = @ec2.run_instances('ami-08856161')[:instances][0][:id]
    id2 = @ec2.run_instances('ami-08856161')[:instances][0][:id]
    @pool.audit_existing_instances
    assert_equal(2, @pool.size)   
  end

  def test_audit_existing_instances_delete
    id1 = 'iid-fake1'
    @pool.add(id1, 'dns-1')
    id2 = @ec2.run_instances('ami-08856161')[:instances][0][:id]
    @pool.add(id2, 'dns-2')
    assert_equal(2, @pool.size)
    @pool.audit_existing_instances
    # one is known, te other is not
    assert_equal(1, @pool.size)    
  end

  def test_start_n_instances
    assert_equal(0, @pool.size)
    @pool.start_n_instances(2)
    assert_equal(2, @pool.size)
  end

  def test_stop_instances
    @pool.start_n_instances(2)
    assert_equal(2, @pool.size)
    @pool.stop_instances([@pool.find{|i| true}])
    assert_equal(1, @pool.size)
  end

  def test_shut_down
    @pool.start_n_instances(2)
    assert_equal(2, @pool.size)
    inst = [@pool.find{|i| true}]
    sd = @pool.shut_down(inst)
    assert_equal(sd, inst)
  end
end