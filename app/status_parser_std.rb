# The standard implementation of status parser
require 'yaml'

module Cloudmaster
  class StatusParserStd

    def parse_message(body)
      YAML.load(body)
    end
  end
end
