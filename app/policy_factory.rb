# This is a factory for Policy implementations.
require 'factory'

module Cloudmaster
  class PolicyFactory 
    include Factory
    def PolicyFactory.create(policy_name, *params)
      name = policy_name.nil? ? 'default' : policy_name.to_s
      require 'policy_' + name.downcase
      class_name = 'Policy' +name.capitalize
      policy = Factory.create_object_from_string(class_name, *params)
      raise "Bad configuration -- no policy #{class_name}" unless policy
      policy
    end
  end
end
