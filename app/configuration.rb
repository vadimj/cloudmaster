require 'inifile'
require 'basic_configuration'
require 'pp'

# Configuration
# Read an ini file and create a configuration.
# The configuration contains the aws configuration, the defaults, and all the pool sections.

module Cloudmaster

  class Configuration < BasicConfiguration
    attr_reader :default, :pools

    # Create a config structure by reading the given config_filenames.
    # The base class handles the aws config and the default config.
    def initialize(config_files = [], opts = [])
      @pools = []
      @default = {}
      @opts = opts
      # search for config files in this directory too
      super(config_files, [ File.dirname(__FILE__)])
      @default.merge!({:user_data => { 
        :aws_env => @aws[:aws_env],
        :aws_access_key => @aws[:aws_access_key],
	:aws_secret_key => @aws[:aws_secret_key]}})
    end

    def refresh
      @pools = []
      @default = {}
      super
    end

    private

    # Read the config file
    def read(config_file)
      ini = super(config_file)
      return nil unless ini
      
      @default.merge!(ini['default'])

      # Handle each of the pool sections
      ini.each_section do |section|
        vals = ini[section]
        # Look for sections of the form Pool-<name>
        if section.index("pool-") == 0
	  name = section[5..-1].to_sym
	  vals[:name] = name
	  @pools << section_config(vals) if @opts.empty? || @opts.include?(name)
	end
      end
    end

    # Supply the section defaults, based on the aws config and the section name.
    # If there is no name, then there are no defaults,
    # TODO Most of these should be hanled by policy or its subclasses.
    def section_defaults(name)
      return nil unless name
      { 
        # generic
        :ami_name => "#{@aws[:aws_user]}-ami-#{name}",
        :security_groups => [name.to_s],
	:key_pair_name => "#{@aws[:aws_user]}-kp",
	# policy plugin
        :work_queue_name => "#{name}-work",
        :status_queue_name => "#{name}-status",
        :manual_queue_name => "#{name}-manual",
	# active_set plugin
        :active_set_bucket => "#{@aws[:aws_bucket]}",
        :active_set_key => "active-set/#{name}-instances",
        :active_set_item => "active-set-#{name}-instances",
        :active_set_queue_name => "#{name}-active-set",
      }
    end

    # Perform configuration for a single section of the config file.
    # If the conventions for image names, queues, and bucket
    # is followed, then this is all the aws configuration needed.
    # This associates a policy symbol with the instance.
    def section_config(config)
      section_defaults(config[:name]).merge(config)
    end
  end
end
