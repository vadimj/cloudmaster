require 'aws_context'

# This implementation of ActiveSet writes the active set to S3.

module Cloudmaster
  class ActiveSetS3
    def initialize(config)
      @s3 = AwsContext.instance.s3
      @config = config
    end

    private

    public

    def valid?
      @config[:active_set_bucket] && @config[:active_set_key]
    end

    def update(active_set)
      @s3.create_object(@config[:active_set_bucket], 
          @config.append_env(@config[:active_set_key]), :data => active_set)
    end
  end
end