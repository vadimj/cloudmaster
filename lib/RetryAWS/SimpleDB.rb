require 'AWS/SimpleDB'

# RetryAWS wraps the AWS module in code that retries it if it fails.
#
module RetryAWS
  class SimpleDB
    def initialize(access_key, secret_key)
      @simple_db = AWS::SimpleDB.new(access_key, secret_key)
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

    def retry?(err, retry_time)
      if err.response.code >= 500 && retry_time < @retry_limit
        sleep retry_time
	return retry_time * 2
      end
      nil
    end

    public

    def list_domains(max_domains = 100)
      retry_time = 1
      begin
        @simple_db.list_domains(max_domains)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error []
      rescue
        report_error []
      end
    end
    
    def create_domain(domain_name)
      retry_time = 1
      begin
        @simple_db.create_domain(domain_name)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error false
      rescue
        report_error false
      end
    end

    def delete_domain(domain_name)
      retry_time = 1
      begin
        @simple_db.delete_domain(domain_name)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error false
      rescue
        report_error false
      end
    end

    def put_attributes(domain_name, item_name, attributes, replace=false)
      retry_time = 1
      begin
        @simple_db.put_attributes(domain_name, item_name, attributes, replace)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error false
      rescue
        report_error false
      end
    end

    def delete_attributes(domain_name, item_name, attributes = {})
      retry_time = 1
      begin
        @simple_db.delete_attributes(domain_name, item_name, attributes)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error false
      rescue
        report_error false
      end
    end

    def get_attributes(domain_name, item_name, attribute_name = nil)
      retry_time = 1
      begin
        @simple_db.get_attributes(domain_name, item_name, attribute_name)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error {}
      rescue
        report_error {}
      end
    end

     def query(domain_name, query_expression=nil, options={:fetch_all=>true})
      retry_time = 1
      begin
        @simple_db.query(domain_name, query_expression, options)
      rescue AWS::ServiceError => err
        retry if retry_time = retry?(err, retry_time)
        report_error {}
      rescue
        report_error {}
      end
    end
  end
end
