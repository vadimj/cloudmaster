$:.unshift(File.join(ENV['AWS_HOME'], "lib", "OriginalAWS"))
require 'OriginalAWS/IAM'

module AWS
  class IAM
    def initialize(*args)
      @iam = ::IAM.new(*args)
    end

    def method_missing(key, *args)
      @iam.send(key, *args)
    end
  end
end
