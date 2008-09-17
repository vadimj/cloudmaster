# Logs to a string.
# This is useful in testing so that we can read back what
# was put into the log, to see if it was what was expected.
class StringLogger
  def initialize(*params)
    @log = StringIO.new("", "w")
  end
  def close
  end

  def puts(msg)
    @log.puts(msg)
  end

  def string
    @log.string
  end

  alias debug puts
  alias info puts
  alias notice puts
  alias warning puts
  alias err puts
  alias error err
  alias alert puts
  alias emerg puts
  alias crit puts
end

