require 'aws_object'
require 'aws_api_actions'

class Ec3Object < AwsObject
  @endpoint_uri = URI.parse("https://ec2.amazonaws.com")
  @api_version = '2009-11-30'
end


