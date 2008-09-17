#
# This class represents the INI file and can be used to parse INI files.
# Derived from IniFile gem, found on http://rubyforge.org/projects/inifile/
#
class IniFile

  #
  # call-seq:
  #    IniFile.load( filename )
  #    IniFile.load( filename, options )
  #
  # Open the given _filename_ and load the contents of the INI file.
  # The following _options_ can be passed to this method:
  #
  #    :comment => ';'      The line comment character(s)
  #    :parameter => '='    The parameter / value separator
  #
  def self.load( filename, opts = {} )
    if filename 
      new(filename, opts)
    else
      nil
    end
  end

  def initialize( filename, opts = {} )
    @fn = filename
    @comment = opts[:comment] || '#'
    @param = opts[:parameter] || '='
    @ini = Hash.new {|h,k| h[k] = Hash.new}

    @rgxp_comment = /^\s*$|^\s*[#{@comment}]/
    @rgxp_section = /^\s*\[([^\]]+)\]/
    @rgxp_param   = /^([^#{@param}]+)#{@param}(.*)$/

    parse
  end

  #
  # call-seq:
  #    each {|section, parameter, value| block}
  #
  # Yield each _section_, _parameter_, _value_ in turn to the given
  # _block_. The method returns immediately if no block is supplied.
  #
  def each
    return unless block_given?
    @ini.each do |section,hash|
      hash.each do |param,val|
        yield section, param, val
      end
    end
    self
  end

  #
  # call-seq:
  #    each_section {|section| block}
  #
  # Yield each _section_ in turn to the given _block_. The method returns
  # immediately if no block is supplied.
  #
  def each_section
    return unless block_given?
    @ini.each_key {|section| yield section}
    self
  end

  #
  # call-seq:
  #    ini_file[section]
  #
  # Get the hash of parameter/value pairs for the given _section_.
  #
  def []( section )
    return nil if section.nil?
    @ini[section.to_s]
  end

  #
  # call-seq:
  #    has_section?( section )
  #
  # Returns +true+ if the named _section_ exists in the INI file.
  #
  def has_section?( section )
    @ini.has_key? section.to_s
  end

  #
  # call-seq:
  #    sections
  #
  # Returns an array of the section names.
  #
  def sections
    @ini.keys
  end

  private

  def cleanup(str)
    str = str.strip
    first = str[0..0]; last = str[-1..-1]
    str = str[1..-2] if first == last && (first == '"' || first == "'")
  end
  #
  # call-seq
  #    parse
  #
  # Parse the ini file contents.
  #
  def parse
    return unless ::Kernel.test ?f, @fn
    section = nil

    ::File.open(@fn, 'r') do |f|
      while line = f.gets
        line = line.chomp

        case line
        # ignore blank lines and comment lines
        when @rgxp_comment: next

        # this is a section declaration
        when @rgxp_section: section = @ini[$1.strip.downcase]

        # otherwise we have a parameter
        when @rgxp_param
          begin
	    val = $2.strip
	    val = val[1..-2] if val[0..0] == "'" || val[-1..-1] == '"'
            section[$1.strip.downcase.to_sym] = val
          rescue NoMethodError
            raise "Bad configuration - inifile parameter encountered before first section"
          end

        else
          raise "Bad configuration -- inifile could not parse line '#{line}"
        end
      end
    end
  end

end



