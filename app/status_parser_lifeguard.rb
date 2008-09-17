# The standard implementation of status parser
require 'rexml/document'
require 'time'

# Process a message as sent from Linfguard.
# Convert it into a form usable with pob pools.
# If we want to make an accurate load estimate, we need to take
# the last interval into account, and average over some time period.
module Cloudmaster
  class StatusParserLifeguard

    # Parse a lifeguard message.
    def parse_message(body)
      msg = { :type => 'status'}
      doc = REXML::Document.new(body)
      doc.root.each_element do |elem|
        val = elem.get_text.to_s.lstrip.rstrip
        case elem.name
        when 'InstanceId'
          msg[:instance_id] = val
        when 'State'
	  case val
	  when 'busy'
	    # Lifeguard's busy maps into active
	    msg[:state] = 'active'
	    msg[:load_estimate] = 1
	  else
	    # all else maps to idle
	    msg[:state] = 'idle'
	    msg[:load_estimate] = 0
	  end    
        when 'Timestamp'
	  if ! val.include?('-')
	    # This is a mock time
	    msg[:timestamp] = Clock.at(val.to_i)
	  elsif val.include?('T')
	    # This is a time in xmlschema form
	    msg[:timestamp] = Clock.xmlschema(val)
	  else
	    # OK, let's try plain parse (don't expect this to happen)
	    msg[:timestamp] = Clock.parse(val)
	  end
        end
      end
      msg
    end
  end
end
