require 'AWS/S3'

module SafeAWS
  class S3
    def initialize(access_key, secret_key)
      @s3 = AWS::S3.new(access_key, secret_key)
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

    # Create an S3 object.
    # Catch errors, but if one occurs, return false.
    def create_object(bucket_name, object_key, opts={})
      begin
        @s3.create_object(bucket_name, object_key, opts)
      rescue
        report_error false
      end
    end

    def get_object(bucket_name, object_key, headers={})
      begin
        if block_given?
          @s3.get_object(bucket_name, object_key, headers) do |segment|
            yield(segment)
	  end
        else
          @s3.get_object(bucket_name, object_key, headers)
	end
      rescue
        report_error nil
      end
    end

    def set_canned_acl(canned_acl, bucket_name, object_key='')
      begin
        @s3.set_canned_acl(canned_acl, bucket_name, object_key)
      rescue
        report_error false
      end
    end
  end
end
