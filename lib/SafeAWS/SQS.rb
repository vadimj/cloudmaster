require 'AWS/SQS'

module SafeAWS
  # Wrap SQS routines that we use.
  # Catch exceptions and return something reasonable.
  class SQS
    def initialize(*params)
      @sqs = AWS::SQS.new(*params)
      @@log = STDOUT
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

    public

    def create_queue(queue_name, visibility_timeout_secs = nil)
      begin
        @sqs.create_queue(queue_name, visibility_tmeout_secs)
      rescue
        report_error nil
      end
    end

    def list_queues(queue_name_prefix = nil)
      begin
        @sqs.list_queues(queue_name_prefix)
      rescue
        report_error []
      end
    end

    def receive_messages(queue_url, maximum=1, visibility_timeout=nil)
      begin
        @sqs.receive_messages(queue_url, maximum, visibility_timeout)
      rescue
        report_error []
      end
    end

    def send_message(queue_url, message_body, encode=false)
      begin
        @sqs.send_message(queue_url, message_body, encode)
      rescue
        report_error ''
      end
    end

    def delete_message(queue_url, message_id)
      begin
        @sqs.delete_message(queue_url, message_id)
      rescue
        report_error false
      end
    end

    def get_queue_attributes(queue_url, attribute='All')
      begin
        @sqs.get_queue_attributes(queue_url, attribute)
      rescue
        report_error {}
      end
    end
  end
end
