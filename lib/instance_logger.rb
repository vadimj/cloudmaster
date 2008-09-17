# The instance logger writes to a file in a given directory.
# The file is determined by the instance_id in the message.
# The file is opened and closed each time something is written.
class InstanceLogger
  def initialize(dir)
    @directory = dir
  end

  def puts(instance, msg)
    File.open(File.join(@directory, instance), "a") do |fd|
      fd.puts msg
    end
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

