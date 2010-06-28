require 'base64'
require 'AWS'
require 'class_level_inheritable_attributes'
require 'aws_inflector'
require 'uri'

class AwsObject
  include ClassLevelInheritableAttributes
  cattr_inheritable :endpoint_uri, :api_version, :signature_version, :http_method, :xml_member_element
  cattr_inheritable :create_operation, :update_operation, :describe_operation, :delete_operation
  cattr_inheritable :fields, :multi_fields, :field_classes, :field_encoders

  # Base64-encodes a string, and removes the excess newline ('\n')
  # characters inserted by the default ruby encoder.
  def encode_base64(data)
    return nil if not data
    b64 = Base64.encode64(data)
    cleaned = b64.gsub("\n","")
    return cleaned
  end

  def self.parse_element elem
    new(elem)
  end

  def self.parse_xml xml_doc
    object_name = deparserize(self.name)
    member_element = @xml_member_element || "//#{object_name}s/member"
    objects = []
    xml_doc.elements.each(member_element) do |elem|
      objects << new(elem)
    end
    return objects
  end
end

module AwsObjectBuilder
  def self.included(base)
    base.extend(ClassMethods)
    base.class_eval do
      include AwsInflector
      include InstanceMethods
      @fields = []
      @multi_fields = []
      @field_classes = {}
      @field_encoders = {}
    end
  end

  module ClassMethods
    def field name, klass = nil
      @fields ||= []
      @fields << name.to_sym
      setup_field name, klass
      @fields
    end
    def encoder name, encoder_function
      @field_encoders ||= {}
      @field_encoders[name.to_sym] = encoder_function
      field name
      @field_encoders
    end
    def multi_field name, klass = nil
      @multi_fields ||= []
      @multi_fields << name.to_sym
      setup_field name, klass
      @multi_fields
    end
    def setup_field name, klass = nil
      @field_classes ||= {}
      @field_classes[name.to_sym] = camelize(klass.to_s) unless klass.nil?
      class_eval %(
        attr_accessor :#{name}
      )
    end
  end

  module InstanceMethods
    #
    # Convenient instance methods to retrieve class variables
    #
    [ :create_operation, :update_operation, :describe_operation, :delete_operation, :fields, :field_encoders, :multi_fields, :field_classes ].each do |method|
      define_method(method) do
        self.class.instance_variable_get("@#{method}")
      end
    end

    #
    # Construct a new AWSObject from either a hash or an xml
    #
    def initialize(options = {})
      if options.is_a? Hash
        options.each do |key, value|
          # skip nil values
          unless value.nil?
            # the class of the variable
            klass = field_classes[key]
            # the parser for the variable
            parser = self.class.parserize(klass) unless klass.nil?
            if fields.include? key
              # if the class is defined - construct an object from the value
              value = self.class.constantize(klass).new(value) unless klass.nil?
              instance_variable_set("@#{key}", value) unless value.nil?
            elsif multi_fields.include? key
              if value.is_a? Array
                ar = []                
                value.each do |v|
                  # if the class is defined - construct an object from the value
                  v = self.class.constantize(parser).new(v) unless parser.nil?
                  ar << v                  
                end
                instance_variable_set("@#{key}", ar) if ar.size > 0
              else
                raise "#{klass}.#{key} should be an Array"
              end
            end
          end
        end
      else
        fields.each do |f|
          el = options.elements[self.class.camelize(f.to_s)]
          unless el.nil?
            klass = field_classes[f]
            # the parser for the variable
            parser = self.class.parserize(klass) unless klass.nil?
            value = klass.nil? ? el.text : self.class.constantize(parser).new(el)
            instance_variable_set("@#{f}", value) unless value.nil?
          end
        end
        multi_fields.each do |f|
          ar = []
          el_name = self.class.camelize(f.to_s)+'/member'
          options.elements.each(el_name) do |el|
            klass = field_classes[f]
            # the parser for the variable
            parser = self.class.parserize(klass) unless klass.nil?
            value = klass.nil? ? el.text : self.class.constantize(parser).new(el)
            ar << value unless value.nil?
          end
          instance_variable_set("@#{f}", ar) if ar.size > 0
        end
      end
    end

    def to_parameters
      result = {}
      
      fields.each do |f|
        klass = field_classes[f]
        encoder = field_encoders[f]
        
        value = instance_variable_get("@#{f}")
        unless encoder.nil?
          method_object = self.method(encoder)
          value = method_object.call(value)
        end
        unless value.nil?
          v = klass.nil? ? value : value.to_parameters
          result[self.class.camelize(f.to_s)] = v
        end
      end
      
      multi_fields.each do |f|
        klass = field_classes[f]
        value = instance_variable_get("@#{f}")
        unless value.nil?
          i = 1
          value.each do |v|
            if klass.nil?
              result[self.class.camelize(f.to_s)+'.member.'+i.to_s] = v
            else
              v.fields.each do |m_field|
                m_value = v.instance_variable_get("@#{m_field}")
                unless m_value.nil?
                  result[self.class.camelize(f.to_s)+'.member.'+i.to_s+'.'+self.class.camelize(m_field.to_s)] = m_value
                end                
              end            
            end
            i += 1
          end
        end
      end
      
      # remove any nil or empty values
      result.delete_if{ |key, value| value.nil? or (value.is_a? Array and value.size == 0) }
      return result
    end
  end

  def to_hash
    attributes = Hash.new
    self.instance_variables.each {|x| attributes[x[1..-1]] = self.instance_variable_get(x) }
    return attributes
  end
  
end
