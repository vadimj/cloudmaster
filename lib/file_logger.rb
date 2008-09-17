# The default logger writes to a file descriptor.
# This could be an actual file, or a stream such as STDOUT.
class FileLogger
  def initialize(file = nil, *args)
    case
    when file.nil?
      @fd = STDOUT
      @needs_close = false
    when file.is_a?(String)
      @fd = File.new(file, "a")
      @needs_close = true
    else
      @fd = file
      @needs_close = false
    end
  end

  def puts(msg)
    @fd.puts msg
  end

  def close
    @fd.close if @needs_close
  end

  alias debug puts
  alias info puts
  alias notice puts
  alias warning puts
  alias err puts
  alias error puts
  alias alert puts
  alias emerg puts
  alias crit puts
end

