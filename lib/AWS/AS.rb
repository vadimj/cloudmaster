$:.unshift(File.join(ENV['AWS_HOME'], "lib", "OriginalAWS"))
require 'OriginalAWS/AS'

module AWS
  class AS
    def initialize(*args)
      @as = ::AS.new(*args)
    end

    def method_missing(key, *args)
      @as.send(key, *args)
    end
  end
end
