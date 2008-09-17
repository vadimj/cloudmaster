
require 'AWS/SQS'
require 'AWS/EC2'
require 'AWS/S3'
require 'AWS/SimpleDB'
require 'SafeAWS/SQS'
require 'SafeAWS/EC2'
require 'SafeAWS/S3'
require 'SafeAWS/SimpleDB'
require 'RetryAWS/SQS'
require 'RetryAWS/EC2'
require 'RetryAWS/S3'
require 'RetryAWS/SimpleDB'
require 'MockAWS/EC2'
require 'MockAWS/S3'
require 'MockAWS/SQS'
require 'MockAWS/SimpleDB'
require 'logger'

# Make sure there is a Clock implementation.
# If not, supply one.
# Caller may supply a mock implementation instead of the standard one.
begin
  Clock.now
rescue
  require 'clock'
end

# Creates and caches EC2, SQS, and S3 interface implementations.
# Can serve up AWS, SafeAWS, RetryAWS, or MockAWS interfaces.
# Every time we create one, we reset the interfaces by forcing the
# creation of new objects.
# This is treated as a global.  It is initialized by calling "AwsContext.setup"
# and then anyone can get a copy by calling "AwsContext.instance".  
class AwsContext
  private_class_method :new
  @@instance = nil

  def initialize(context, logger)
    @context = context
    @logger = logger
    @ec2 = @sqs = @s3 = @sdb = nil
  end

  # Create a AwsContext.
  #
  # The context here can be one of 
  #  * :aws -- use the standard AWS interface
  #  * :safe -- use the SafeAWS interface
  #  * :retry -- use the RetryAWS interface
  #  * :mock -- use the MockAWS interface
  #
  # The interface is established the first time you use it.  The 
  # returned interface is retained, and used for subsequent requests.
  # Thus only one instance of each interface is created.
  def AwsContext.setup(context, logger = nil)
    @@instance = new(context, logger)
  end

  # Return the instance that was already created.
  # If none created yet, then create AWS context.
  def AwsContext.instance
    if @@instance.nil?
      setup(:aws)
    end
    @@instance
  end

  private

  # Create an EC2 interface.
  def create_ec2(*params)
    case @context
    when :aws
     @ec2 = AWS::EC2.new(*params)
    when :safe
     @ec2 = SafeAWS::EC2.new(*params)
    when :retry
     @ec2 = RetryAWS::EC2.new(*params)
    when :mock
     @ec2 = MockAWS::EC2.new(*params)
     @ec2.reset
     @ec2.logger = @logger if @logger
    end
    @ec2
  end

  # Create an sqs interface.
  def create_sqs(*params)
    case @context
    when :aws
     @sqs = AWS::SQS.new(*params)
    when :safe
     @sqs = SafeAWS::SQS.new(*params)
    when :retry
     @sqs = RetryAWS::SQS.new(*params)
    when :mock
     @sqs = MockAWS::SQS.new(*params)
     @sqs.reset
     @sqs.logger = @logger if @logger
    end
    @sqs
  end

  # Create an S3 interface.
  def create_s3(*params)
    case @context
    when :aws
     @s3 = AWS::S3.new(*params)
    when :safe
     @s3 = SafeAWS::S3.new(*params)
    when :retry
     @s3 = RetryAWS::S3.new(*params)
    when :mock
     @s3 = MockAWS::S3.new(*params)
     @s3.logger = @logger if @logger
     @s3.reset
    end
    @s3
  end

  # Create a SimpleDB interface.
  def create_sdb(*params)
    case @context
    when :aws
     @sdb = AWS::SimpleDB.new(*params)
    when :safe
     @sdb = SafeAWS::SimpleDB.new(*params)
    when :retry
     @sdb = RetryAWS::SimpleDB.new(*params)
    when :mock
     @sdb = MockAWS::SimpleDB.new(*params)
     @sdb.logger = @logger if @logger
     @sdb.reset
    end
    @sdb
  end

  public

  # Return an EC2 interface.  Create on if needed.
  # Note that the parameters (if given) are only used if the interface is created.
  def ec2(*params)
    @ec2 || create_ec2(*params)
  end

  # Return an SQS interface.  Create on if needed.
  # Note that the parameters (if given) are only used if the interface is created.
  def sqs(*params)
    @sqs || create_sqs(*params)
  end

  # Return a S3 interface.  Create on if needed.
  # Note that the parameters (if given) are only used if the interface is created.
  def s3(*params)
    @s3 || create_s3(*params)
  end

  # Return a SimpleDB interface.  Create on if needed.
  # Note that the parameters (if given) are only used if the interface is created.
  def sdb(*params)
    @sdb || create_sdb(*params)
  end

end
