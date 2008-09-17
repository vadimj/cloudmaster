require 'aws_context'

module Cloudmaster

  # Provides enumerators for EC2 images.
  # The information is read once from EC2 and stored.
  # It is then enumearted one image at a time.
  # The stored list of images can also be searched 
  # Get the EC2 images and store them.
  # Allow lookup by matching on the name.
  class EC2ImageEnumerator
    include Enumerable

    # Create the enumerator.  Fetch and store the complete image list.
    def initialize
      @images = AwsContext.instance.ec2.describe_images
    end

    # Enumerate each image
    def each
      @images.each { |image| yield image }
    end

    # Look for the image with the given name.
    # Return the image id if exactly one is found, throw exception otherwise.
    # Uses the set of images we fetched in the constructor and stored.
    # The fetch is slow, so we don't want to repeat it.
    def find_image_id_by_name(image_name)
      filter = Regexp.new(image_name)
      images = find_all {|i| i[:location] =~ /#{image_name}/}
      case images.length
      when 0
        raise "Bad Configuration -- image #{image_name} not found"
      when 1
        images[0][:id]
      else
        raise "Bad configuration -- multiple images #{image_name}"
      end
    end
  end
end
