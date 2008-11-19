$:.unshift(File.join(ENV['AWS_HOME'], "lib", "OriginalAWS"))
require 'OriginalAWS/S3'

module AWS
  class S3
    def initialize(*args)
      @s3 = ::S3.new(*args)
    end

    def method_missing(key, *args, &block)
      @s3.send(key, *args, &block)
    end
  end
end