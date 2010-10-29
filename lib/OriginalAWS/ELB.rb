require 'AWS'
require 'aws_object'
require 'aws_api_actions'

class ElbObject < AwsObject
  @endpoint_uri = URI.parse("https://elasticloadbalancing.amazonaws.com")
end

class HealthCheckParser < ElbObject
  include AwsObjectBuilder
  @create_operation = 'ConfigureHealthCheck'

  field :load_balancer_name
  field :target
  field :interval
  field :timeout
  field :healthy_threshold
  field :unhealthy_threshold
end

class ListenerParser < ElbObject
  include AwsObjectBuilder
  
  field :load_balancer_port
  field :instance_port
  field :protocol
end

class LoadBalancerParser < ElbObject
  include AwsObjectBuilder
  @xml_member_element = '//LoadBalancerDescriptions/member'
  
  field :load_balancer_name
  field :created_time
  field :d_n_s_name
  field :health_check, :health_check
  multi_field :availability_zones
  multi_field :instances, :elb_instance
  multi_field :listeners, :listener
end

class CreateLoadBalancerResultParser < ElbObject
  @xml_member_element = '//CreateLoadBalancerResult'
  
  include AwsObjectBuilder
  field :d_n_s_name
end

class AvailabilityZoneParser < ElbObject
  include AwsObjectBuilder
  @create_operation = 'EnableAvailabilityZonesForLoadBalancer'
  @delete_operation = 'DisableAvailabilityZonesForLoadBalancer'
  
  field :load_balancer_name
  multi_field :availability_zones
end

class ElbInstanceParser < ElbObject
  include AwsObjectBuilder
  @create_operation = 'RegisterInstancesWithLoadBalancer'
  @delete_operation = 'DeregisterInstancesFromLoadBalancer'
  
  field :load_balancer_name
  field :instance_id
  multi_field :instances
end

class ELB
  include AwsApiActions
  
  aws_object :load_balancer, :availability_zone, :instance, :health_check
end
