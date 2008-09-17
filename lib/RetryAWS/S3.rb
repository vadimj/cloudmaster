require 'AWS/S3'

module RetryAWS
  class S3
    def initialize(access_key, secret_key)
      @s3 = AWS::S3.new(access_key, secret_key)
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
      if err.response.code >= 500 && retry_time < @retry_limit
        sleep retry_time
	return retry_time * 2
      end
      nil
    end

    public

    # Create an S3 object.
    # Catch errors, but if one occurs, return false.
    def create_object(bucket_name, object_key, opts={})
      retry_time = 1
      begin
        @s3.create_object(bucket_name, object_key, opts)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error false
      rescue
        report_error false
      end
    end

    def get_object(bucket_name, object_key, headers={})
      retry_time = 1
      begin
        if block_given?
          @s3.get_object(bucket_name, object_key, headers) do |segment|
            yield(segment)
	  end
        else
          @s3.get_object(bucket_name, object_key, headers)
	end
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error nil
      rescue
        report_error nil
      end
    end

    def set_canned_acl(canned_acl, bucket_name, object_key='')
      retry_time = 1
      begin
        @s3.set_canned_acl(canned_acl, bucket_name, object_key)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error false
      rescue
        report_error false
      end
    end
  end
end
