$:.unshift(File.join(ENV['AWS_HOME'], "lib", "OriginalAWS"))
require 'OriginalAWS/ELB'

module AWS
  class ELB
    def initialize(*args)
      @as = ::ELB.new(*args)
    end

    def method_missing(key, *args)
      @as.send(key, *args)
    end
  end
end
