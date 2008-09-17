
# Used to mock Time 

class Clock
  attr_accessor :time
  include Comparable

  @@current_time = 0

  def initialize(time)
    @time = time
  end

  def Clock.at(time)
    Clock.new(time)
  end

  def Clock.now
    Clock.new(@@current_time)
  end

  def Clock.hour
    (@@current_time/3600).floor
  end

  def to_s
    @time.to_s
  end

  def +(time)
    Clock.new(time + @time)
  end

  def -(clock)
    @time - clock.time
  end

  def <=>(other)
    @time <=> other.time
  end

  def strftime(format)
    @time.to_s
  end
    
  def Clock.sleep(numeric = 0)
    @@current_time += numeric
  end

  def Clock.xmlschema(tm)
    Clock.new(Time.xmlschema(tm).to_i)
  end

  def Clock.parse(tm)
    Clock.new(Time.parse(tm).to_i)
  end

##############
#  testing
  def Clock.reset
    @@current_time = 0
  end

  def Clock.set(numeric)
    @@current_time = numeric
  end
end
