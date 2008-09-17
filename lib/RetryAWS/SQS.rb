require 'AWS/SQS'

module RetryAWS
  # Wrap SQS routines that we use.
  # Catch exceptions and return something reasonable.
  class SQS
    def initialize(*params)
      @sqs = AWS::SQS.new(*params)
      @@log = STDOUT
      @retry_limit = 16
    end

    def logger=(logger)
      @@log = logger
    end

    private

    # report error and return result
    def report_error(res)
      @@log.puts "error #{$!}"
      $@.each {|line| @@log.puts "  #{line}"}
      res
    end

    def retry?(err, retry_time)
pp err
      if err.response.code.to_i >= 500 && retry_time < @retry_limit
        sleep retry_time
	return retry_time * 2
      end
      nil
    end

    public

    def list_queues(queue_name_prefix = nil)
      retry_time = 1
      begin
        @sqs.list_queues(queue_name_prefix)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error []
      rescue
        report_error []
      end
    end

    def create_queue(queue_name, visibility_timeout_secs = nil)
      retry_time = 1
      begin
        @sqs.create_queue(queue_name, visibility_timeout_secs)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error nil
      rescue
        report_error nil
      end
    end

    def receive_messages(queue_url, maximum=1, visibility_timeout=nil)
      retry_time = 1
      begin
        @sqs.receive_messages(queue_url, maximum, visibility_timeout)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error []
      rescue
        report_error []
      end
    end

    def send_message(queue_url, message_body, encode=false)
      retry_time = 1
      begin
        @sqs.send_message(queue_url, message_body, encode)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error ''
      rescue
        report_error ''
      end
    end

    def delete_message(queue_url, message_id)
      retry_time = 1
      begin
        @sqs.delete_message(queue_url, message_id)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error false
      rescue
        report_error false
      end
    end

    def get_queue_attributes(queue_url, attribute='All')
      retry_time = 1
      begin
        @sqs.get_queue_attributes(queue_url, attribute)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error({})
      rescue
        report_error({})
      end
    end
  end
end
