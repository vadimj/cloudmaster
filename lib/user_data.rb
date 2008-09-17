# This class loads user data.

require 'open-uri'
require 'yaml'

class UserData
  # Load user data
  def self.load
    begin
      iid = open('http://169.254.169.254/latest/meta-data/instance-id').read(200)
      user_data = open('http://169.254.169.254/latest/user-data').read(2000)
      data = YAML.load(user_data)
      aws = { :aws_env => data[:aws_env],
            :aws_access_key => data[:aws_access_key],
            :aws_secret_key => data[:aws_secret_key]
	    }
    rescue
      # when running locally, use fake iid
      iid = "unknown"
      user_data = nil
      aws = {}        
    end
    @@data = {:aws => aws, :iid => iid, :user_data => user_data}
    @@data
  end

  def self.keys
    [@@data[:aws][:aws_access_key], @@data[:aws][:aws_secret_key]] if @@data
  end
end