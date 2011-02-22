require 'AWS'
require 'aws_object'
require 'aws_api_actions'

class ElbObject < AwsObject
  @endpoint_uri = URI.parse("https://elasticloadbalancing.amazonaws.com")
  @api_version = '2010-07-01'
end

class AppCookieStickinessPolicyParser < ElbObject
  @xml_member_element = '//Policies/AppCookieStickinessPolicies/member'
  
  include AwsObjectBuilder
  @create_operation = 'CreateAppCookieStickinessPolicy'
  
  field :cookie_name
  field :policy_name

  field :load_balancer_name
end

# ConfigureHealthCheckResult
class CreateHealthCheckResultParser < ElbObject
  @xml_member_element = '//ConfigureHealthCheckResult'

  include AwsObjectBuilder
  field :health_check, :health_check_description
end

class CreateLoadBalancerResultParser < ElbObject
  @xml_member_element = '//CreateLoadBalancerResult'
  
  include AwsObjectBuilder
  field :d_n_s_name
end

# DeregisterInstancesFromLoadBalancerResult
class DeleteInstanceResultParser < ElbObject
  @xml_member_element = '//DeregisterInstancesFromLoadBalancerResult'
  
  include AwsObjectBuilder
  multi_field :instances, :elb_instance
end

# DescribeInstanceHealthResult
class DescribeInstanceStatesResultParser < ElbObject
  @xml_member_element = '//DescribeInstanceHealthResult'
  
  include AwsObjectBuilder
  multi_field :instance_states, :instance_state
end

class DescribeLoadBalancersResultParser < ElbObject
  @xml_member_element = '//DescribeLoadBalancersResult'
  
  include AwsObjectBuilder
  multi_field :load_balancer_descriptions, :load_balancer_description
end

# DisableAvailabilityZonesForLoadBalancerResult
class DeleteAvailabilityZoneResultParser < ElbObject
  @xml_member_element = '//DisableAvailabilityZonesForLoadBalancerResult'
  
  include AwsObjectBuilder
  multi_field :availability_zones
end

# EnableAvailabilityZonesForLoadBalancerResult
class CreateAvailabilityZoneResultParser < ElbObject
  @xml_member_element = '//EnableAvailabilityZonesForLoadBalancerResult'
  
  include AwsObjectBuilder
  multi_field :availability_zones
end

class HealthCheckDescriptionParser < ElbObject
  include AwsObjectBuilder

  field :healthy_threshold
  field :interval
  field :target
  field :timeout
  field :unhealthy_threshold
end

class HealthCheckParser < ElbObject
  include AwsObjectBuilder
  @create_operation = 'ConfigureHealthCheck'

  field :load_balancer_name
  field :health_check, :health_check_description
end

class ElbInstanceParser < ElbObject
  include AwsObjectBuilder
  @create_operation = 'RegisterInstancesWithLoadBalancer'
  @delete_operation = 'DeregisterInstancesFromLoadBalancer'
  
  field :load_balancer_name
  field :instance_id
  multi_field :instances
end

class InstanceStateParser < ElbObject
  include AwsObjectBuilder
  @describe_operation = 'DescribeInstanceHealth'
  
  field :description
  field :instance_id
  field :reason_code
  field :state
  
  multi_field :instances
  field :load_balancer_name
end

class LBCookieStickinessPolicyParser < ElbObject
  @xml_member_element = '//LBCookieStickinessPolicies/member'

  include AwsObjectBuilder
  @create_operation = 'CreateLBCookieStickinessPolicy'
  
  field :cookie_expiration_period
  field :policy_name
  
  field :load_balancer_name
end

class ListenerParser < ElbObject
  include AwsObjectBuilder
  @create_operation = 'CreateLoadBalancerListener'
  @delete_operation = 'DeleteLoadBalancerListener'
  
  field :instance_port
  field :load_balancer_port
  field :protocol
  field :s_s_l_certificate_id
end

class ListenerDescriptionParser < ElbObject
  include AwsObjectBuilder
  @xml_member_element = '//ListenerDescriptions/member'

  field :listener, :listener
  multi_field :policy_names
end

# LoadBalancerDescription
class LoadBalancerParser < ElbObject
  include AwsObjectBuilder
  @xml_member_element = '//LoadBalancerDescriptions/member'
  @create_operation = 'CreateLoadBalancer'
  @delete_operation = 'DeleteLoadBalancer'
  @describe_operation = 'DescribeLoadBalancers'
  
  multi_field :availability_zones
  field :created_time
  field :d_n_s_name
  field :health_check, :health_check_description
  multi_field :instances, :elb_instance
  multi_field :listener_descriptions, :listener_description
  field :load_balancer_name
  field :policies, :elb_policy
end

class ElbPolicyParser < ElbObject
  include AwsObjectBuilder
  @create_operation = 'SetLoadBalancerPoliciesOfListener'
  @delete_operation = 'DeleteLoadBalancerPolicy'
  
  multi_field :app_cookie_stickiness_policies, :app_cookie_stickiness_policy
  multi_field :l_b_cookie_stickiness_policies, :l_b_cookie_stickiness_policy
  field :load_balancer_name
  field :load_balancer_port
  field :s_s_l_certificate_id
  field :policy_name
end

# RegisterInstancesWithLoadBalancerResultParser
class CreateInstanceResultParser < ElbObject
  @xml_member_element = '//RegisterInstancesWithLoadBalancerResult'
  
  include AwsObjectBuilder
  multi_field :instances, :elb_instance
end

class AvailabilityZoneParser < ElbObject
  include AwsObjectBuilder
  @create_operation = 'EnableAvailabilityZonesForLoadBalancer'
  @delete_operation = 'DisableAvailabilityZonesForLoadBalancer'
  
  field :load_balancer_name
  multi_field :availability_zones
end

class SSLCertificate < ElbObject
  include AwsObjectBuilder
  @create_operation = 'SetLoadBalancerListenerSSLCertificate'

  field :load_balancer_name
  field :load_balancer_port
  field :s_s_l_certificate_id
end

class CreateAppCookieStickinessPolicyResultParser < ElbObject
  @xml_member_element = '//CreateAppCookieStickinessPolicyResult'
  
  include AwsObjectBuilder
end

class CreateLBCookieStickinessPolicyResultParser <ElbObject
  @xml_member_element = '//CreateLBCookieStickinessPolicyResult'
  
  include AwsObjectBuilder
end

class ELB
  include AwsApiActions
  
  aws_object :health_check
  aws_object :app_cookie_stickiness_policy
  aws_object :l_b_cookie_stickiness_policy
  aws_object :load_balancer
  aws_object :listener
  aws_object :elb_policy
  aws_object :instance
  aws_object :instance_state
  aws_object :availability_zone
  aws_object :s_s_l_certificate
end
