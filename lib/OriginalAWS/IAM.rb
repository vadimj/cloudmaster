require 'aws_object'
require 'aws_api_actions'

class IamObject < AwsObject
    @endpoint_uri = URI.parse("https://iam.amazonaws.com")
    @api_version = '2010-01-01'
end

class ResponseMetadataParser < IamObject
    include AwsObjectBuilder

    field :request_id
end

class GroupParser < IamObject
    include AwsObjectBuilder
    @describe_operation = 'ListGroups'
  
    field :arn
    field :path
    field :group_name
    field :group_id

    # ListGroups fields    
    field :path_prefix
    field :user_name
end

class CreateGroupResultParser < GroupParser
    @xml_member_element = '//CreateGroupResult/Group'
end

class UserParser < IamObject
    include AwsObjectBuilder
  
    field :path
    field :user_name
end

class IAM
    include AwsApiActions
  
    aws_object :group, :user
end
