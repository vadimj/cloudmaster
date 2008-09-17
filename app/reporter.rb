require 'instance_logger'

module Cloudmaster

  # Creates and outputs log messages
  # These are formatted with a timestamp and an instance name.
  # This remembers the log device, which is anything with puts.
  # This is treated as a global.  It is initialized by calling "Reporter.setup"
  # and then anyone can get a copy by calling "Reporter.instance".  
  class Reporter
    attr_accessor :level

    NONE = 0
    ERROR = 1
    WARNING = 2
    INFO = 3
    TRACE = 4
    DEBUG = 5
    ALL = 10

    # Reporter displays the given name on every line.
    # reports go to the given log (an IO).
    def initialize(name, log)
      @level = ALL
      @name = name
      @log = log || STDOUT
      @instance_logger = nil
    end

    def Reporter.setup(name, log)
      new(name, log)
    end

    def log_instances(dir)
      @instance_logger = InstanceLogger.new(dir)
    end

    # Log a message 
    def log(message, *opts)
      send_to_log("INFO:", message, *opts)
    end

    def err(msg, *opts)
      send_to_log("ERROR:", msg, *opts) if @level >= ERROR
    end
    alias error err

    def warning(msg, *opts)
      send_to_log("WARNING:", msg, *opts) if @level >= WARNING
    end

    def info(msg, *opts)
      send_to_log("INFO:", msg, *opts) if @level >= INFO
    end

    def trace(msg, *opts)
      send_to_log("TRACE:", msg, *opts) if @level >= TRACE
    end

    def debug(msg, *opts)
      send_to_log("DEBUG:", msg, *opts) if @level >= DEBUG
    end

    private

    def send_to_log(type, message, instance_id = nil)
      msg = [type, format_timestamp(Clock.now), @name]
      msg << instance_id if instance_id
      msg << message
      message = msg.join(' ')
      @log.puts(message)
      if instance_id && @instance_logger
	@instance_logger.puts(instance_id, message)
      end
    end

    def format_timestamp(ts)
       "#{Clock.now.strftime("%m-%d-%y %H:%M:%S")}"   
    end
  end
end
