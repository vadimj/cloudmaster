require 'aws_object'
require 'aws_api_actions'

class AsObject < AwsObject
  @endpoint_uri = URI.parse("https://autoscaling.amazonaws.com")
end

class BlockDeviceMappingParser < AsObject
  include AwsObjectBuilder
  
  field :virtual_name
  field :device_name
end

class LaunchConfigurationParser < AsObject
  include AwsObjectBuilder
  
  field :launch_configuration_name
  field :instance_type
  field :image_id
  field :ramdisk_id
  field :kernel_id
  field :key_name
  field :user_data
  field :created_time
  multi_field :load_balancer_names
  multi_field :security_groups
  multi_field :block_device_mappings, :block_device_mapping
end

class AutoScalingGroupParser < AsObject
  include AwsObjectBuilder
  
  field :auto_scaling_group_name
  field :cooldown
  field :launch_configuration_name
  field :min_size
  field :max_size
  field :desired_capacity

  multi_field :availability_zones
  multi_field :load_balancer_names
end

class AS
  include AwsApiActions
  
  aws_object :launch_configuration, :auto_scaling_group
end
