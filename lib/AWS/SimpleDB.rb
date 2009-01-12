$:.unshift(File.join(ENV['AWS_HOME'], "lib", "OriginalAWS"))
require 'OriginalAWS/SimpleDB'

module AWS
  class SimpleDB
    def initialize(*args)
      @ec2 = ::SimpleDB.new(*args)
    end

    def method_missing(key, *args)
      @ec2.send(key, *args)
    end
  end
end
