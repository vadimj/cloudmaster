require 'basic_configuration'
require 'aws_context'
require 'user_data'
require 'yaml'
require 'open-uri'
require 'pp'

# Sample, meant to run on an Amazon EC2 instance.
# 
# It monitors another subsystem (in this case a Darwin Streaming Server)
# and provides periodic load estimates.
class MonitorDarwin
  def initialize(instance_id, work_queue_name, status_queue_name)
    @instance_id = instance_id
    @shutdown = false
    config = BasicConfiguration.new
    @sqs = AwsContext.instance.sqs(*config.keys)
    # These are credentials that allow access to the Darwin Server
    @account = 'dss-admin'
    @password = 'dss-admin01'
    @dss_info = nil
    begin
      @work_queue = @sqs.list_queues(work_queue_name).first
      if @work_queue.nil?
        puts "error #{$!} #{work_queue_name}"
        raise "no work queue"
      end
      @status_queue = @sqs.list_queues(status_queue_name).first
      if @status_queue.nil?
        puts "error #{$!} #{status_queue_name}"
        raise "no status queue"
      end
    rescue
      puts "error #{$!}"
      raise "cannot list queues"
    end
  end

  # Send a status message, containing the load average,
  # to cloudmaster through the status queue.
  def send_status_message(load_average, connections)
    msg = { :type => 'status', 
      :instance_id => @instance_id, 
      :state => 'active',
      :load_estimate => load_average, 
      :connections => connections,
      :timestamp => Time.now}
    body = YAML.dump(msg)
#    puts "sending #{body}"
    @sqs.send_message(@status_queue, body)
  end

  # Send a log message to cloudmaster over the status queue.
  def send_log_message(message)
    puts message
    msg = { :type => 'log', :instance_id => @instance_id, :message => message,
      :timestamp => Time.now}
    body = YAML.dump(msg)
    @sqs.send_message(@status_queue, body)
  end

  # Get information from the Darwin server to allow us to 
  # estimate its load.
  def get_dss_info(key)
    opts = { :http_basic_authentication => [@account, @password]}
    uri="http://localhost:554/modules/admin/server/#{key}"
    res = nil
    open(uri, "r", opts) do |f|
      re = Regexp.new("^#{File.basename(key)}=\"(.*)\"$")
      while ! f.eof?
        line = f.gets
        #puts line
        if line =~ re
          #puts "match: #{$1}"
          res = $1
        end
      end
    end
    res 
  end

  # Get info from Darwin server and extract relevant items.
  def get_dss
    info_items = ['qtssRTPSvrCurConn',
      'qtssMP3SvrCurConn',
      'qtssSvrCPULoadPercent',
      'qtssRTPSvrCurBandwidth',
      'qtssMP3SvrCurBandwidth',
      'qtssSvrPreferences/maximum_connections',
      'qtssSvrPreferences/maximum_bandwidth']

    begin
      @dss_info = info_items.inject({}) {|out, i| out[i] = get_dss_info(i); out}
    rescue
      @dss_info = {}
    end
  end

  # Return the number of connections currently in use.
  def curr_connections
    @dss_info["qtssRTPSvrCurConn"].to_f + 
      @dss_info["qtssMP3SvrCurConn"].to_f
  end

  # Copute the estimated load.
  def load_average
    maximum = @dss_info["qtssSvrPreferences/maximum_connections"].to_f
    maximum == 0 ? 0 : curr_connections / maximum
  end

  # Send a status message.
  def send_status(load, connections)
    send_status_message(load, connections)
  end

  # run the monitor.
  def run
    while ! @shutdown
      get_dss
      load = load_average
      conn = curr_connections.round
      send_status(load, conn)
      send_log_message("load: #{load} connections: #{conn}")
      sleep 60
    end
  end

  # Shut down the monitor.
  def shutdown
    @shutdown = true
  end
end

user_data = UserData.load
mon = MonitorDarwin.new(user_data[:iid], 'darwin-work', 'darwin-status')

# Catch interrupts
Signal.trap("INT") do
  mon.shutdown
end

mon.run
