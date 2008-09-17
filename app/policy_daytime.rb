require 'policy'

module Cloudmaster

  # Provide example daytime policy
  # This increases the pool size during the day.
  # This is provided as part of an example on how to create custom policies.
  class PolicyDaytime < Policy
    # Define the adjust function increase the pool in the
    #  daytime if it is below daytime minimum
    def adjust
      hour = Clock.hour
      return 0 if hour < 10 || hour > 17
      return 0 if @instances.size >= @config[:minimum_number_of_instances_daytime].to_i
      return 1
    end
  end
end