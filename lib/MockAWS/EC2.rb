
# Mock SQS
# Provide just enough for cloudmaster.
module MockAWS
  # Mock EC2
  class EC2
    @@log = STDOUT
    @@images = [
       {:owner_id=>"452272755447",
        :state=>"available",
        :id=>"ami-08856161",
        :is_public=>false,
        :location=>"chayden/chayden-ami-primes-test.img.manifest.xml"},
       {:owner_id=>"452272755447",
        :state=>"available",
        :id=>"ami-3f856156",
        :is_public=>false,
        :location=>"chayden/chayden-ami-base.img.manifest.xml"},
       {:owner_id=>"452272755447",
        :state=>"available",
        :id=>"ami-d18064b8",
        :is_public=>false,
        :location=>"chayden/chayden-ami-fibonacci-test.img.manifest.xml"},
    ]

    @@running = []
    @@instance_id = 0

    def initialize(*params)
    end

    def describe_images(options={})
      @@images
    end

    def describe_instances(instance_ids=[])
      instances = []
      if instance_ids.size > 0 
        instance_ids.each do |id|
          instances += @@running.find_all {|r| r[:id] == id}
        end
      else
        instances = @@running
      end
      [{:instances => instances}]
    end
    
    def run_instances(image_id, min_count=1, max_count=min_count, options={})
      ids = []
      max_count.times do
        @@instance_id += 1
	iid = "i-#{@@instance_id}"
        starting = {:image_id => image_id, :id => iid, 
          :public_dns => "", :state => "running"}
        @@log.puts "***** starting #{iid} #{image_id}"
        @@running << starting
        ids << {:id => iid}
      end
      {:instances => ids}
    end

    def terminate_instances(instance_ids = [])
      instance_ids.each do |id|
        @@log.puts "***** terminating #{id}"
        @@running = @@running.find_all { |r| r[:id] != id }
      end
    end

#######################################3333
#  for testing
    def logger=(logger)
      @@log = logger
    end

    def pp_running
      pp @@running
    end

    def count
      @@running.size
    end

    def valid_ami_id
      @@images[0][:id]
    end

    def set_public_dns(id, dns)
      @@running.each do |inst|
        if inst[:id] == id
	  inst[:public_dns] = dns
	end
      end
    end

    def get_public_dns(id)
      inst = @@running.find {|inst| inst[:id] == id}
      inst.nil? ? "" : inst[:public_dns]
    end

    def set_state(id, state)
      @@running.each do |inst|
        if inst[:id] == id
	  inst[:state] = state
	end
      end
    end

    def first_id
      @@running.first[:id]
    end

    def reset
      @@log = STDOUT
      @@running = []
      @@instance_id = 0
    end

  end
end
