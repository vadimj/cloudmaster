module MockAWS
  # Mock SQS
  class SQS
    @@log = STDOUT
    @@queues = ["http://queue.amazonaws.com/A13T024T56MRDD/manual-manual-test",
     "http://queue.amazonaws.com/A13T024T56MRDC/fib-status-test",
     "http://queue.amazonaws.com/A13T024T56MRDC/fib-work-test",
     "http://queue.amazonaws.com/A13T024T56MRDC/primes-status-test",
     "http://queue.amazonaws.com/A13T024T56MRDC/primes-work-test"]

    @@messages = {}
    @@queues.each {|q| @@messages[q] = []}
    @@attributes = {"ApproximateNumberOfMessages"=>0, "VisibilityTimeout"=>300}
    @@msg_seq = 1

    def initialize(*params)
    end

    def logger=(logger)
      @@log = logger
    end

    def create_queue(queue_name, visibility_timeout_secs = nil)
      @@queues << queue_name
      @@queues.last
    end

    def list_queues(queue_name_prefix = nil)
      filter = Regexp.new(queue_name_prefix)
      @@queues.find_all {|q| q =~ filter}
    end

    def receive_messages(queue_url, maximum=1, visibility_timeout=nil)
      if @@messages[queue_url] == []
        []
      else
        visible = @@messages[queue_url].find_all {|m| m[:visible]}
        @@log.puts "***** receiving #{visible.first[:id]} #{visible.first[:body]}"
        [visible.first]
      end
    end

    def send_message(queue_url, message_body, encode=false)
      mid = "id-#{@@msg_seq}"
      message = { :id => mid, 
        :body => message_body,
	:visible => true}
      @@msg_seq += 1
      @@messages[queue_url] = [] unless @@messages[queue_url]
      @@messages[queue_url] << message
      @@log.puts "***** sending #{File.basename(queue_url)} #{mid} => #{message_body}"
      true
    end

    def delete_message(queue_url, message_id)
      @@messages[queue_url] = @@messages[queue_url].reject {|m| m[:id] == message_id}
      true
    end


    def get_queue_attributes(queue_url, attribute='All')
      @@attributes["ApproximateNumberOfMessages"] = @@messages[queue_url].size
      @@attributes
    end

######################
# testing
    def reset
      @@log = STDOUT
      @@queues = ["http://queue.amazonaws.com/A13T024T56MRDD/manual-manual-test",
       "http://queue.amazonaws.com/A13T024T56MRDC/fib-status-test",
       "http://queue.amazonaws.com/A13T024T56MRDC/fib-work-test",
       "http://queue.amazonaws.com/A13T024T56MRDC/primes-status-test",
       "http://queue.amazonaws.com/A13T024T56MRDC/primes-work-test"]

      @@messages = {}
      @@queues.each {|q| @@messages[q] = []}
      @@attributes = {"ApproximateNumberOfMessages"=>0, "VisibilityTimeout"=>300}
      @@msg_seq = 1
    end
  end
end
