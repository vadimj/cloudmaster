require 'policy'

module Cloudmaster

  # Provide fixed policy.
  # This never adjusts the size of the pool.
  # PolicyFixed is still useful, because it still ensures that the number
  # of instances stay beteen the maximum and minimum (because this is
  # enforced in the base class apply).
  class PolicyFixed < Policy
    # Use everything from the base class.

    # Adjust never changes instances.
    def adjust
      0
    end
  end

end