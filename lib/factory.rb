# This contains common factory methods.

module Factory
  # Given a class name as a string, create an instance of that class
  # and initialize it with the given arguments.
  def Factory.create_object_from_string(class_name, *args)
    ObjectSpace.each_object(Class) do |x|
      if x.name == class_name || x.name == "Cloudmaster::#{class_name}"
        return x.new(*args)
      end
    end
    nil
  end
end