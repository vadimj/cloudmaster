require 'AWS/EC2'

# RetryAWS wraps the AWS module in exception catcher blocks, so that any
# exceptions that are thrown do not affect the caller.
#
# The RetryEC2, RetrySQS, and RetryS3 log any errors that they encounter, so
# that they can be examined later.
module RetryAWS
  # Wrap EC2 functions that we use.
  # Catch errors and do something reasonable.
  class EC2
    def initialize(access_key, secret_key)
      @ec2 = AWS::EC2.new(access_key, secret_key)
      @@log = STDOUT
      @retry_limit = 16
    end

    def logger=(logger)
      @@log = logger
    end

    private

    def report_error(res)
      @@log.puts "error #{$!}"
      $@.each {|line| @@log.puts "  #{line}"}
      res
    end

    def retry?(err, retry_time)
      if err.response.code.to_i >= 500 && retry_time < @retry_limit
        sleep retry_time
	return retry_time * 2
      end
      nil
    end

    public 

    def describe_images(options={})
      retry_time = 1
      begin
        @ec2.describe_images(options)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error []
      rescue
        report_error []
      end
    end
    
    def describe_instances(instance_ids=[])
      retry_time = 1
      begin
        @ec2.describe_instances(instance_ids)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error []
      rescue
        report_error []
      end
    end

    def run_instances(image_id, min_count=1, max_count=min_count, options={})
      retry_time = 1
      begin
        @ec2.run_instances(image_id, min_count, max_count, options)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error []
      rescue
        report_error []
      end
    end

    def terminate_instances(instance_ids = [])
      retry_time = 1
      begin
        @ec2.terminate_instances(instance_ids)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error []
      rescue
        report_error []
      end
    end
  end
end
