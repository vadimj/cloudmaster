$:.unshift(File.join(ENV['AWS_HOME'], "lib", "OriginalAWS"))
require 'OriginalAWS/EC2'

module AWS
  class EC2
    def initialize(*args)
      @ec2 = ::EC2.new(*args)
    end

    def method_missing(key, *args)
      @ec2.send(key, *args)
    end
  end
end