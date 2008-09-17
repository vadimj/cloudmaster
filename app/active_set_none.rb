# This implementation of ActiveSet does nothing
# It is appropriate when you don't want the active set.

module Cloudmaster
  class ActiveSetNone
    def initialize(config)
    end

    def valid?
      true
    end

    def update(active_set)
    end
  end
end
