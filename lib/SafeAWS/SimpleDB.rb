require 'AWS/SimpleDB'

# SafeAWS wraps the AWS module in exception catcher blocks, so that any
# exceptions that are thrown do not affect the caller.
#
# The SafeEC2, SafeSQS, SafeSimpleDB, and SafeS3 log any errors that they encounter, so
# that they can be examined later.
module SafeAWS
  # Wrap SimpleDB functions that we use.
  # Catch errors and do something reasonable.
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

    public

    def list_domains(max_domains = 100)
      begin
        @simple_db.list_domains(max_domains)
      rescue
        report_error []
      end
    end
    
    def create_domain(domain_name)
      begin
        @simple_db.create_domain(domain_name)
      rescue
        report_error false
      end
    end

    def delete_domain(domain_name)
      begin
        @simple_db.delete_domain(domain_name)
      rescue
        report_error false
      end
    end

    def put_attributes(domain_name, item_name, attributes, replace=false)
      begin
        @simple_db.put_attributes(domain_name, item_name, attributes, replace)
      rescue
        report_error false
      end
    end

    def delete_attributes(domain_name, item_name, attributes = {})
      begin
        @simple_db.delete_attributes(domain_name, item_name, attributes)
      rescue
        report_error false
      end
    end

    def get_attributes(domain_name, item_name, attribute_name = nil)
      begin
        @simple_db.get_attributes(domain_name, item_name, attribute_name)
      rescue
        report_error {}
      end
    end

     def query(domain_name, query_expression=nil, options={:fetch_all=>true})
      begin
        @simple_db.query(domain_name, query_expression, options)
      rescue
        report_error {}
      end
    end

  end
end
