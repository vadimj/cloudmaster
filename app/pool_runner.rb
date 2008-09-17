require 'pool_configuration'
require 'pool_manager'

module Cloudmaster

  #  oolRunner
  #
  #  Manages separate PoolManagers, each in a separate thread.
  #  
  #  Knows how to start (run) and stop (shutdown) the pools.
  #
  # Creates a thread for each pool in config, and runs a PoolManager in it.
  # This needs to be passed a configuration, normally a InifileConfig object
  # The configuration object contains all the information needed to control
  # the pools, including the number of pools and each one's characteristics.
  class PoolRunner
    attr_reader :pool_managers   # for testing only
    # Create empty runner.  Until the run method is called, the
    #  individual pool managers are not created.
    def initialize(config)
      @config = config
      @pool_managers = []
      Signal.trap("INT") do
        self.shutdown
      end
    end

    # Create each of the pool managers described in the configuration.
    # We can limit the amount of time it runs, for testing purposes only
    # In testing we can call run again after it returns, so we make sure
    # that we only create pool managers the first time through.
    def run(limit = nil)
     if @pool_managers == []
        @config.pools.each do |pool_config|
          # Wrap pool config parameters up with defaults.
          config = PoolConfiguration.new(@config.aws, @config.default, pool_config)
          @pool_managers << PoolManager.new(config)
        end
      end
      threads = []
      @pool_managers.each do |pool_manager|
        threads << Thread.new(pool_manager) do |mgr|
          mgr.run(limit)
        end
      end
      threads.each { |thread| thread.join }
    end

    # Shut down each of the pool managers.
    def shutdown
      @pool_managers.each { |mgr| mgr.shutdown }
    end
  end
end
