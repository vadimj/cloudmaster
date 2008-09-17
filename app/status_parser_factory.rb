# This is a factory for StatusParser implementations.
require 'factory'

module Cloudmaster
  class StatusParserFactory 
    include Factory
    def StatusParserFactory.create(type, *params)
      name = type.nil? ? 'none' : type.to_s
      require 'status_parser_' + name.downcase
      class_name = 'StatusParser' + name.capitalize
      status_parser = Factory.create_object_from_string(class_name, *params)
      raise "Bad configuration -- bad status_parser_set #{class_name}" unless status_parser
      status_parser
    end
  end
end
