$:.unshift(File.join(ENV['AWS_HOME'], "app"))
require 'test/unit'
require 'MockAWS/clock'
require 'logger_factory'
require 'aws_context'
require 'ec2_instance_enumerator'
require 'ec2_image_enumerator'
require 'pp'

# tests the EC2ImageEnumerator and the C2InstanceEnumerators.
class EnumeratorTests < Test::Unit::TestCase
  def setup
    LoggerFactory.setup("/tmp/test.out")
    logf = LoggerFactory.create(:file)
    @ec2 = AwsContext.setup(:mock, logf).ec2
    @image_enum = Cloudmaster::EC2ImageEnumerator.new
    @inst_enum =  Cloudmaster::EC2InstanceEnumerator.new
  end

  def test_each
    images = []
    @image_enum.each {|i| images << i}
    assert_equal(3, images.size)
  end

  def test_find_image_id_by_name
    id = @image_enum.find_image_id_by_name("ami-primes-test")
    assert_equal('ami-08856161', id)
    assert_raise(RuntimeError) do
      id = @image_enum.find_image_id_by_name("xxx")
    end
    assert_raise(RuntimeError) do
      id = @image_enum.find_image_id_by_name("test")
    end
  end

  def test_instance_each
    inst = []
    @inst_enum.each {|i| inst << i}
    assert_equal(0, inst.size)
    id1 = @ec2.run_instances('ami-08856161')[:instances][0][:id]
    @inst_enum =  Cloudmaster::EC2InstanceEnumerator.new
    inst = []
    @inst_enum.each {|i| inst << i}
    assert_equal(1, inst.size)
  end
end
