require 'AWS/SimpleDB'

module MockAWS
  class SimpleDB
    def initialize(*params)
    end

    def list_domains(max_domains = 100)
      []
    end
    
    def create_domain(domain_name)
      true
    end

    def delete_domain(domain_name)
      true
    end

    def put_attributes(domain_name, item_name, attributes, replace=false)
      true
    end

    def delete_attributes(domain_name, item_name, attributes = {})
      true
    end

    def get_attributes(domain_name, item_name, attribute_name = nil)
      true
    end

     def query(domain_name, query_expression=nil, options={:fetch_all=>true})
       true
     end
##############
#  testing
    def logger=(logger)
      @@log = logger
    end

    def reset
      @context = []
    end

  end
end
