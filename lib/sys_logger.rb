require 'syslog'

# Logs using the syslog facility.
class SysLogger
  def initialize(dummy, program_name)
    @log = Syslog.open(program_name)
  end

  def close
  end
  def puts(msg)
    @log.info(msg)
  end
  def debug(msg)
    @log.debug(msg)
  end
  def info(msg)
    @log.info(msg)
  end
  def notice(msg)
    @log.notice(msg)
  end
  def warning(msg)
    @log.warning(msg)
  end
  def err(msg)
    @log.err(msg)
  end
  def alert(msg)
    @log.alert(msg)
  end
  def emerg(msg)
    @log.emerg(msg)
  end
  def crit(msg)
    @log.crit(msg)
  end
  alias error err
end

