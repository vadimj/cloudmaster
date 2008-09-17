# This is a factory for ActiveSet implementations.
require 'factory'

module Cloudmaster
  class ActiveSetFactory 
    include Factory
    def ActiveSetFactory.create(type, *params)
      name = type.nil? ? 'none' : type.to_s
      require 'active_set_' + name.downcase
      class_name = 'ActiveSet' + name.capitalize
      active_set = Factory.create_object_from_string(class_name, *params)
      raise "Bad configuration -- bad active_set #{class_name}" unless active_set
      active_set
    end
  end
end
