require 'factory'
require 'sys_logger'
require 'string_logger'
require 'file_logger'

class LoggerFactory 
  include Factory
  @@filename = 'logfile'
  @@program = 'unknown'

  def LoggerFactory.setup(filename, program = 'unknown')
    @@filename = filename
    @@program = program
  end

  def LoggerFactory.create(type, *params)
    filename = filename || @@filename
    program = program || @@program
    name = type.to_s
    require name.downcase + '_logger'
    class_name = name.capitalize + 'Logger'
    logger = Factory.create_object_from_string(class_name, filename, program)
    raise "Bad configuration -- no logger #{class_name}" unless logger
    logger

#    case type.to_s
#    when 'syslog'
#      SysLogger.new(program)
#    when 'string'
#      StringLogger.new
#    when 'stdout'
#      FileLogger.new(STDOUT, false)
#    when 'file'
#      FileLogger.new(File.new(filename, "a"), true)
#    end
  end
end

