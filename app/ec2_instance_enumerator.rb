require 'aws_context'

module Cloudmaster

  # Provides an enumerator for EC2 instances.
  # Query for instances when object created.
  # Handles all instances we own, or just ones maching a list of ids.
  class EC2InstanceEnumerator
    include Enumerable

    # Get the list of instances from EC2
    def initialize(*ids)
      @instances =  AwsContext.instance.ec2.describe_instances(*ids)
    end

    # Enumerator each instance
    def each
      @instances.each do |group| 
        group[:instances].each do |instance|
          yield instance
        end
      end
    end
  end
end
