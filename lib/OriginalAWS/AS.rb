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
  field :created_time
  field :max_records
  encoder :user_data, :encode_base64
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
  multi_field :instances, :instance
  multi_field :triggers, :trigger
end

class DesiredCapacity < AsObject
  include AwsObjectBuilder
  @create_operation = 'SetDesiredCapacity'

  field :auto_scaling_group_name
  field :desired_capacity
end

class DimensionParser < AsObject
  include AwsObjectBuilder
  
  field :name
  field :value
end

class InstanceParser < AsObject
  include AwsObjectBuilder
  @delete_operation = 'TerminateInstanceInAutoScalingGroup'

  field :instance_id
  field :lifecycle_state
  field :availability_zone
  field :should_decrement_desired_capacity
end

class TriggerParser < AsObject
  include AwsObjectBuilder
  @create_operation = 'CreateOrUpdateScalingTrigger'
  
  field :trigger_name
  field :auto_scaling_group_name
  # Valid Values: CPUUtilization | NetworkIn | NetworkOut | DiskWriteOps | DiskReadBytes | DiskReadOps | DiskWriteBytes
  field :measure_name
  # Valid Values: Minimum | Maximum | Sum | Average
  field :statistic
  # Constraints: must be a multiple of 60
  field :period
  # Valid Values: Seconds | Percent | Bytes | Bits | Count | Bytes/Second | Bits/Second | Count/Second | None.
  field :unit
	
  field :lower_threshold
  # Constraints: Must be a positive or negative integer followed by a % sign.
  # If you specify only a positive or negative number, then the AutoScalingGroup increases or decreases by the specified number of actual instances.
  # If you specify a positive or negative number with a percent sign, the AutoScaling group increases or decreases by the specified percentage.
  field :lower_breach_scale_increment
  field :upper_threshold
  # Constraints: Must be a positive or negative integer followed by a % sign.
  # If you specify only a positive or negative number, then the AutoScalingGroup will increase or decrease by the specified number of actual instances.
  # If you specify a positive or negative number with a percent sign, the AutoScaling group will increase or decrease by the specified percentage.
  field :upper_breach_scale_increment
  # Constraints: Must be a multiple of 60
  field :breach_duration 

  field :namespace
  multi_field :dimensions, :dimension
  # Custom units are currently not available.
  #  field :custom_unit
end

class ScalingActivityParser < AsObject
  include AwsObjectBuilder
  @describe_operation = 'DescribeScalingActivities'
  
  field :activity_id
  field :auto_scaling_group_name
  field :cause
  field :description
  field :end_time
  field :start_time
  field :progress
  field :status_code
  field :status_message
  field :max_records
end

class DesiredCapacityParser < AsObject
  include AwsObjectBuilder
  @create_operation = 'SetDesiredCapacity'

  field :auto_scaling_group_name
  field :desired_capacity
end

class AS
  include AwsApiActions
  
  aws_object :launch_configuration, :auto_scaling_group, :trigger, :scaling_activity, :desired_capacity, :instance
end
