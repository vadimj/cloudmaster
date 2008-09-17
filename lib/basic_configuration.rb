require 'inifile'
require 'pp'

# BasicConfiguration
# Read an ini file and create a configuration.
# The configuration contains the aws configuration only.

class BasicConfiguration
  attr_reader :aws

  # Default list of config files to search for
  DEFAULT_CONFIG_FILES = ['aws-config.ini', 'default-config.ini', 'config.ini']
  # Search for config files in these directories
  DEFAULT_SEARCH_PATH = [ ".", ENV['AWS_HOME'], ENV['HOME'], File.dirname(__FILE__)]

  @@config_files = DEFAULT_CONFIG_FILES
  @@search_path = DEFAULT_SEARCH_PATH

  # Set up the list of config files that is read when looking for configurations.
  # If this is not called, a default set of files is read.
  def BasicConfiguration.setup_config_files(config_files = [])
    @@config_files = config_files
  end

  # Set up the search path.
  # If this is not called, a default path is used
  def BasicConfiguration.setup_search_path(search_path = [])
    @@search_path = search_path
  end

  # Add the given array of files to the list that we read.
  def BasicConfiguration.add_config_files(config_files)
    @@config_files |= config_files
  end

  # Add the following set of search paths to the ones that we use.
  def BasicConfiguration.add_search_paths(search_paths)
    @@search_path |= search_paths
  end

  # Create a config structure by reading the given config_filenames.
  # If config files or search_paths are given, they apply only to this
  # instance, but are retained for use by refresh.
  # Create default aws config items based on environment varbiables, in
  # case we can't find a config file.
  def initialize(config_files = [], search_paths = [])
    @config_files = @@config_files | config_files
    @search_path = @@search_path | search_paths
    refresh
  end

  # Read the configuration from the existing config file using
  # the existing filenames.
  # This is useful for reinitiaizing on a SIGTERM
  def refresh
    @aws = get_aws_from_environment
    read_config
  end

  def keys
    [ @aws[:aws_access_key], @aws[:aws_secret_key]]
  end

  private

  # Looks up an environment variable, and returns the value, if there is one.
  # If the caller asks for some environment variable that is not 
  # present in the environment, then the default is returned.
  def get_environment(var, default = nil)
    ENV[var] || default
  end


  def get_aws_from_environment
    # Get aws config from the environment
    aws_user = get_environment('AWS_USER', 'aws')
    key_file = File.join(ENV['HOME'], 'keys', "#{aws_user}-kp.pem")

    # Set up our credentials from the environment
    # These sere as a default to the credentials in the
    # config.ini file.
    { :aws_env =>  ENV['AWS_ENV'],
      :aws_access_key => get_environment('AWS_ACCESS_KEY'),
      :aws_secret_key => get_environment('AWS_SECRET_KEY'),
      :aws_user => aws_user,
      :aws_bucket => get_environment('AWS_BUCKET'),
      :aws_key => get_environment('AWS_KEY', key_file)
    }
  end

  # Read all the config files in order
  def read_config
    @config_files.each {|config_file| read(config_file)}
  end

  # Read the config file and store aws section.
  def read(config_file)
    ini = IniFile.load(find_on_search_path(config_file))
    return nil unless ini
    # Merge in the items from the 'aws' section, overriding the defaults.
    # This needs to be first, so others can use it.
    @aws.merge!(ini['aws'])
    ini
  end

  # If filename starts with "/" then return it unchanged.
  # Otherwise try various prefixes on it.
  # Return the first one that is actually a file.
  # Retun nil if the file does not exist at any of the places.
  def find_on_search_path(filename)
    return filename if filename[0..0] == File::SEPARATOR
    @search_path.each do |prefix|
      unless prefix.nil?
        fn = File.join(prefix, filename)
        return fn if File.exists?(fn)
      end
    end
    nil
  end
end
