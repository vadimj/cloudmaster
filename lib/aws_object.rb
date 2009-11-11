require 'AWS'
require 'class_level_inheritable_attributes'
require 'aws_inflector'
require 'uri'

class AwsObject
  include ClassLevelInheritableAttributes
  cattr_inheritable :endpoint_uri, :xml_member_element
  cattr_inheritable :fields, :multi_fields, :field_classes

  def self.parse_element elem
    new(elem)
  end
  def self.parse_xml xml_doc
    object_name = self.name.gsub('Parser','')
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
    end
  end

  module ClassMethods
    def field name, klass = nil
      @fields ||= []
      @fields << name.to_sym
      setup_field name, klass
      @fields
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
    [ :fields, :multi_fields, :field_classes ].each do |method|
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
            if fields.include? key
              # if the class is defined - construct an object from the value
              value = self.class.constantize(klass).new(value) unless klass.nil?
              instance_variable_set("@#{key}", value) unless value.nil?
            elsif multi_fields.include? key
              if value.is_a? Array
                ar = []                
                value.each do |v|
                  # if the class is defined - construct an object from the value
                  v = self.class.constantize(klass).new(v) unless klass.nil?
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
            value = klass.nil? ? el.text : self.class.constantize(klass).new(el)
            instance_variable_set("@#{f}", value) unless value.nil?
          end
        end
        multi_fields.each do |f|
          ar = []
          el_name = self.class.camelize(f.to_s)+'/member'
          options.elements.each(el_name) do |el|
            klass = field_classes[f]
            value = klass.nil? ? el.text : self.class.constantize(klass).new(el)
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
        value = instance_variable_get("@#{f}")
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
  
end
