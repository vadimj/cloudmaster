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
    
    # UpdateGroup fields
    field :user_to_add
    field :user_to_remove
end

class CreateGroupResultParser < GroupParser
    @xml_member_element = '//CreateGroupResult/Group'
end

class UpdateGroupResultParser < GroupParser
    @xml_member_element = '//UpdateGroupResult/Group'
end

class PolicyParser < IamObject
    include AwsObjectBuilder
    @create_operation = 'PutPolicy'
    
    field :user_name
    field :group_name
    field :policy_name
    field :policy_document
    
    def self.PREDEFINED_POLICIES
        return {
            'ALL_ON_ALL' => {
                'Statement' => [{
                    'Effect' => 'Allow',
                    'Action' => "*",
                    'Resource' => "*",
                }],
            },
            'ALL_ON_CREDENTIALS' => {
                'Statement' => [{
                    'Effect' => 'Allow',
                    'Action' => ["iam:*AccessKey*","iam:*SigningCertificate*"],
                }],
            },
        }
    end
end

class CreatePolicyResultParser < PolicyParser
end

class UserParser < IamObject
    include AwsObjectBuilder
    @describe_operation = 'ListUsers'
  
    field :arn
    field :path
    field :user_name
    field :user_id

    # ListUsers fields    
    field :path_prefix
end

class CreateUserResultParser < UserParser
    @xml_member_element = '//CreateUserResult/User'
end

class GroupUserParser < UserParser
    @describe_operation = 'GetGroup'
    @xml_member_element = '//GetGroupResult/Users/member'
    
    field :group_name
end

class AccessKeyParser < IamObject
    include AwsObjectBuilder
    @describe_operation = 'ListAccessKeys'
    
    field :user_name
    field :access_key_id
    field :secret_access_key
    field :status
end

class CreateAccessKeyResultParser < AccessKeyParser
    @xml_member_element = '//CreateAccessKeyResult/AccessKey'
end

class SigningCertificateParser < IamObject
    include AwsObjectBuilder
    @create_operation = 'UploadSigningCertificate'
    
    field :user_name
    field :certificate_body
    field :certificate_id
    field :status
end

class CreateSigningCertificateResultParser < SigningCertificateParser
    @xml_member_element = '//UploadSigningCertificateResult/Certificate'
end

class IAM
    include AwsApiActions
  
    aws_object :group, :policy, :user, :group_user, :access_key, :signing_certificate
end
