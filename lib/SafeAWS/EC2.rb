require 'AWS/EC2'

# SafeAWS wraps the AWS module in exception catcher blocks, so that any
# exceptions that are thrown do not affect the caller.
#
# The SafeEC2, SafeSQS, SafeSimpleDB and SafeS3 log any errors that they encounter, so
# that they can be examined later.
module SafeAWS
  # Wrap EC2 functions that we use.
  # Catch errors and do something reasonable.
  class EC2
    def initialize(access_key, secret_key)
      @ec2 = AWS::EC2.new(access_key, secret_key)
      @@log = STDOUT
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

    public

    def describe_images(options={})
      begin
        @ec2.describe_images(options)
      rescue
        report_error []
      end
    end
    
    def describe_instances(instance_ids=[])
      begin
        @ec2.describe_instances(instance_ids)
      rescue
        report_error []
      end
    end

    def run_instances(image_id, min_count=1, max_count=min_count, options={})
      begin
        @ec2.run_instances(image_id, min_count, max_count, options)
      rescue
        report_error []
      end
    end

    def terminate_instances(instance_ids = [])
      begin
        @ec2.terminate_instances(instance_ids)
      rescue
        report_error []
      end
    end
  end
end
