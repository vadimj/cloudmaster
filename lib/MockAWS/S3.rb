module MockAWS
  # Mock S3
  class S3
    @@contents = {}

    def initialize(*params)
    end

    # Create an S3 object.
    def create_object(bucket_name, object_key, opts={})
      key = "#{bucket_name}/#{object_key}"
      value = opts[:data]
      @@contents[key] = value
    end

    # Return an object stored previously
    def get_object(bucket_name, object_key, headers={})
      key = "#{bucket_name}/#{object_key}"
      @@contents[key]
    end

    def set_canned_acl(canned_acl, bucket_name, object_key='')
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

    def contents
      pp @@contents
    end
  end
end
