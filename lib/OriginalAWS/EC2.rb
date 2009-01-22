# Sample Ruby code for the O'Reilly book "Programming Amazon Web
# Services" by James Murty.
#
# This code was written for Ruby version 1.8.6 or greater.
#
# The EC2 module implements the Query API of the Amazon Elastic Compute Cloud
# service.
#
# Extended by Charles Hayden to cover EBS interface extensions.
require 'AWS'

class EC2
  include AWS # Include the AWS module as a mixin

  ENDPOINT_URI = URI.parse("https://ec2.amazonaws.com/")
  API_VERSION = '2008-08-08'
  SIGNATURE_VERSION = '1'

  HTTP_METHOD = 'POST' # 'GET'

  def parse_reservation(elem)
    reservation = {
      :reservation_id => elem.elements['reservationId'].text,
      :owner_id => elem.elements['ownerId'].text,
    }

    group_names = []
    elem.elements.each('groupSet/item') do |group|
      group_names << group.elements['groupId'].text
    end
    reservation[:groups] = group_names

    reservation[:instances] = []
    elem.elements.each('instancesSet/item') do |instance|
      elems = instance.elements
      item = {
        :id => elems['instanceId'].text,
        :image_id => elems['imageId'].text,
        :state => elems['instanceState/name'].text,
        :private_dns => elems['privateDnsName'].text,
        :public_dns => elems['dnsName'].text,
        :type => elems['instanceType'].text,
        :launch_time => elems['launchTime'].text
      }

      item[:reason] = elems['reason'].text if elems['reason']
      item[:key_name] = elems['keyName'].text if elems['keyName']
      item[:index] = elems['amiLaunchIndex'].text if elems['amiLaunchIndex']
      if elems['placement']
        item[:zone] = elems['placement/availabilityZone'].text
      end
      item[:kernel_id] = elems['kernelId'].text if elems['kernelId']
      item[:ramdisk_id] = elems['ramdiskId'].text if elems['ramdiskId']

      if elems['productCodes']
        item[:product_codes] = []
        elems.each('productCodes/item/productCode') do |code|
          item[:product_codes] << code.text
        end
      end

      reservation[:instances] << item
    end

    return reservation
  end

  def parse_volume(elem)
    volume = {
      :volume_id => elem.elements['volumeId'].text,
      :size => elem.elements['size'].text,
      :status => elem.elements['status'].text,
      :create_time => elem.elements['createTime'].text,
      :snapshot_id => elem.elements['snapshotId'].text,
      :availability_zone => elem.elements['availabilityZone'].text,
    }
    attachments = []
    elem.elements.each('attachmentSet/item') do |attachment|
      attachments << {
        :volume_id => attachment.elements['volumeId'].text,
        :instance_id => attachment.elements['instanceId'].text,
        :device => attachment.elements['device'].text,
        :status => attachment.elements['status'].text,
        :attach_time => attachment.elements['attachTime'].text
      }
    end
    volume[:attachment_set] = attachments
    return volume
  end

  def describe_instances(*instance_ids)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DescribeInstances',
      },{
      'InstanceId' => instance_ids
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)

    reservations = []
    xml_doc.elements.each('//reservationSet/item') do |elem|
      reservations << parse_reservation(elem)
    end
    return reservations
  end

  def describe_availability_zones(*names)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DescribeAvailabilityZones',
      },{
      'ZoneName' => names
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)

    zones = []
    xml_doc.elements.each('//availabilityZoneInfo/item') do |elem|
      zones << {
        :name => elem.elements['zoneName'].text,
        :state => elem.elements['zoneState'].text
      }
    end
    return zones
  end

  def describe_keypairs(*keypair_names)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DescribeKeyPairs',
      },{
      'KeyName' => keypair_names
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)

    keypairs = []
    xml_doc.elements.each('//keySet/item') do |key|
      keypairs << {
        :name => key.elements['keyName'].text,
        :fingerprint => key.elements['keyFingerprint'].text
      }
    end

    return keypairs
  end

  def create_keypair(keyname, autosave=true)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'CreateKeyPair',
      'KeyName' => keyname,
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)

    keypair = {
      :name => xml_doc.elements['//keyName'].text,
      :fingerprint => xml_doc.elements['//keyFingerprint'].text,
      :material => xml_doc.elements['//keyMaterial'].text
    }

    if autosave
      # Locate key material and save to a file named after the keyName
      File.open("#{keypair[:name]}.pem",'w') do |file|
        file.write(keypair[:material] + "\n")
        keypair[:file_name] = file.path
      end
    end

    return keypair
  end

  def delete_keypair(keyname)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DeleteKeyPair',
      'KeyName' => keyname,
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    return true
  end

  def describe_images(options={})
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DescribeImages',
      # Despite API documentation, the ImageType parameter is *not* supported, see:
      # http://developer.amazonwebservices.com/connect/thread.jspa?threadID=20655&tstart=25
      # 'ImageType' => options[:type]
      },{
      'ImageId' => options[:image_ids],
      'Owner' => options[:owners],
      'ExecutableBy' => options[:executable_by]
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)

    images = []
    xml_doc.elements.each('//imagesSet/item') do |image|
      image_details = {
        :id => image.elements['imageId'].text,
        :location => image.elements['imageLocation'].text,
        :state => image.elements['imageState'].text,
        :owner_id => image.elements['imageOwnerId'].text,
        :is_public => image.elements['isPublic'].text == 'true',
        :architecture => image.elements['architecture'].text,
        :type => image.elements['imageType'].text
      }
      
      # Items only available when listing 'machine' image types
      # that have associated kernel and ramdisk metadata
      if image.elements['kernelId'] 
        image_details[:kernel_id] = image.elements['kernelId'].text
      end
      if image.elements['ramdiskId']
        image_details[:ramdisk_id] = image.elements['ramdiskId'].text
      end
      
      image.elements.each('productCodes/item/productCode') do |code|
        image_details[:product_codes] ||= []
        image_details[:product_codes] << code.text
      end

      images << image_details
    end

    return images
  end

  def run_instances(image_id, min_count=1, max_count=min_count, options={})
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'RunInstances',
      'ImageId' => image_id,
      'MinCount' => min_count,
      'MaxCount' => max_count,
      'KeyName' => options[:key_name],
      'InstanceType' => options[:instance_type],
      'UserData' => encode_base64(options[:user_data]),
      
      'Placement.AvailabilityZone' => options[:zone],
      'KernelId' => options[:kernel_id],
      'RamdiskId' => options[:ramdisk_id]
      },{
      'SecurityGroup' => options[:security_groups]
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)
    return parse_reservation(xml_doc.root)
  end

  def terminate_instances(*instance_ids)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'TerminateInstances',
      },{
      'InstanceId' => instance_ids,
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)

    instances = []
    xml_doc.elements.each('//instancesSet/item') do |item|
      instances << {
        :id => item.elements['instanceId'].text,
        :state => item.elements['shutdownState/name'].text,
        :previous_state => item.elements['previousState/name'].text
      }
    end

    return instances
  end

  def authorize_ingress_by_cidr(group_name, ip_protocol, from_port,
                              to_port=from_port, cidr_range='0.0.0.0/0')

    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'AuthorizeSecurityGroupIngress',
      'GroupName' => group_name,
      'IpProtocol' => ip_protocol,
      'FromPort' => from_port,
      'ToPort' => to_port,
      'CidrIp' => cidr_range,
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    return true
  end

  def authorize_ingress_by_group(group_name, source_security_group_name,
                                 source_security_group_owner_id)

    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'AuthorizeSecurityGroupIngress',
      'GroupName' => group_name,
      'SourceSecurityGroupName' => source_security_group_name,
      'SourceSecurityGroupOwnerId' => source_security_group_owner_id,
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)

    return true
  end

  def describe_security_groups(*security_group_names)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DescribeSecurityGroups',
      },{
      'GroupName' => security_group_names,
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)

    security_groups = []
    xml_doc.elements.each('//securityGroupInfo/item') do |sec_group|
      grants = []
      sec_group.elements.each('ipPermissions/item') do |item|
        grant = {
          :protocol => item.elements['ipProtocol'].text,
          :from_port => item.elements['fromPort'].text,
          :to_port => item.elements['toPort'].text
        }

        item.elements.each('groups/item') do |group|
          grant[:groups] ||= []
          grant[:groups] << {
            :user_id => group.elements['userId'].text,
            :name => group.elements['groupName'].text
          }
        end

        if item.elements['ipRanges/item']
          grant[:ip_range] = item.elements['ipRanges/item/cidrIp'].text
        end

        grants << grant
      end

      security_groups << {
        :name => sec_group.elements['groupName'].text,
        :description => sec_group.elements['groupDescription'].text,
        :owner_id => sec_group.elements['ownerId'].text,
        :grants => grants
      }
    end

    return security_groups
  end

  def revoke_ingress_by_cidr(group_name, ip_protocol, from_port,
                             to_port=from_port, cidr_range='0.0.0.0/0')

    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'RevokeSecurityGroupIngress',
      'GroupName' => group_name,
      'IpProtocol' => ip_protocol,
      'FromPort' => from_port,
      'ToPort' => to_port,
      'CidrIp' => cidr_range,
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    return true
  end

  def revoke_ingress_by_group(group_name, source_security_group_name,
                              source_security_group_owner_id)

    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'RevokeSecurityGroupIngress',
      'GroupName' => group_name,
      'SourceSecurityGroupName' => source_security_group_name,
      'SourceSecurityGroupOwnerId' => source_security_group_owner_id,
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    return true
  end

  def create_security_group(group_name, group_description=group_name)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'CreateSecurityGroup',
      'GroupName' => group_name,
      'GroupDescription' => group_description,
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    return true
  end

  def delete_security_group(group_name)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DeleteSecurityGroup',
      'GroupName' => group_name,
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    return true
  end


  def register_image(image_location)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'RegisterImage',
      'ImageLocation' => image_location,
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)

    return xml_doc.elements['//imageId'].text
  end

  def deregister_image(image_id)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DeregisterImage',
      'ImageId' => image_id,
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    return true
  end

  def describe_image_attribute(image_id, attribute='launchPermission')
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DescribeImageAttribute',
      'ImageId' => image_id,
      'Attribute' => attribute,
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)

    result = {:id => xml_doc.elements['//imageId'].text}

    if xml_doc.elements['//launchPermission']
      result[:launch_perms_user] = []
      result[:launch_perms_group] = []
      xml_doc.elements.each('//launchPermission/item') do |lp|
        elems = lp.elements
        result[:launch_perms_group] << elems['group'].text if elems['group']
        result[:launch_perms_user] << elems['userId'].text if elems['userId']
      end
    end

    if xml_doc.elements['//productCodes']
      result[:product_codes] = []
      xml_doc.elements.each('//productCodes/item') do |pc|
        result[:product_codes] << pc.text
      end
    end

    return result
  end

  def modify_image_attribute(image_id, attribute,
                             operation_type, attribute_values)

    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'ModifyImageAttribute',
      'ImageId' => image_id,
      'Attribute' => attribute,
      'OperationType' => operation_type,
      }, attribute_values)

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    return true
  end

  def reset_image_attribute(image_id, attribute='launchPermission')
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'ResetImageAttribute',
      'ImageId' => image_id,
      'Attribute' => attribute,
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    return true
  end

  def get_console_output(instance_id)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'GetConsoleOutput',
      'InstanceId' => instance_id,
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    elems = REXML::Document.new(response.body).elements

    return {
      :id => elems['//instanceId'].text,
      :timestamp => elems['//timestamp'].text,
      :output => Base64.decode64(elems['//output'].text).strip
    }
  end

  def reboot_instances(*instance_ids)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'RebootInstances',
      },{
      'InstanceId' => instance_ids,
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    return true
  end


  def confirm_product_instance(product_code, instance_id)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'ConfirmProductInstance',
      'ProductCode' => product_code,
      'InstanceId' => instance_id
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    elems = REXML::Document.new(response.body).elements

    result = {
      :result => elems['//result'].text == true
    }
    result[:owner_id] = elems['//ownerId'].text if elems['//ownerId']
    return result
  end

  def describe_addresses(*addresses)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DescribeAddresses',
      },{
      'PublicIp' => addresses
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)

    addresses = []
    xml_doc.elements.each('//addressesSet/item') do |elem|
      addresses << {
        :public_ip => elem.elements['publicIp'].text,
        :instance_id => elem.elements['instanceId'].text
      }
    end
    return addresses
  end
  
  def allocate_address()
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'AllocateAddress',
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)
    return xml_doc.elements['//publicIp'].text
  end

  def release_address(public_ip)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'ReleaseAddress',
      'PublicIp' => public_ip
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)
    return xml_doc.elements['//return'].text == 'true'
  end

  def associate_address(instance_id, public_ip)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'AssociateAddress',
      'InstanceId' => instance_id,
      'PublicIp' => public_ip
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)
    return xml_doc.elements['//return'].text == 'true'
  end

  def disassociate_address(public_ip)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DisassociateAddress',
      'PublicIp' => public_ip
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)
    return xml_doc.elements['//return'].text == 'true'
  end

  def create_volume(size, availability_zone)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'CreateVolume',
      'Size' => size,
      'AvailabilityZone' => availability_zone
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)
    res = {}
    res[:volume_id] = xml_doc.elements['//volumeId'].text
    res[:size] = xml_doc.elements['//size'].text
    res[:status] = xml_doc.elements['//status'].text
    res[:create_time] = xml_doc.elements['//createTime'].text
    res[:availability_zone] = xml_doc.elements['//availabilityZone'].text
    res[:snapshot_id] = xml_doc.elements['//snapshotId'].text
    res
  end

  def create_volume_from_snapshot(snapshot_id, availability_zone)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'CreateVolume',
      'SnapshotId' => snapshot_id,
      'AvailabilityZone' => availability_zone
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)
    res = {}
    res[:volume_id] = xml_doc.elements['//volumeId'].text
    res[:size] = xml_doc.elements['//size'].text
    res[:status] = xml_doc.elements['//status'].text
    res[:create_time] = xml_doc.elements['//createTime'].text
    res[:availability_zone] = xml_doc.elements['//availabilityZone'].text
    res[:snapshot_id] = xml_doc.elements['//snapshotId'].text
    res
  end

  def delete_volume(volume_id)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DeleteVolume',
      'VolumeId' => volume_id
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)
    return xml_doc.elements['//return'].text == 'true'
  end

  def describe_volumes(*volume_ids)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DescribeVolumes',
      },{
      'VolumeId' => volume_ids
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)
    volumes = []
    xml_doc.elements.each('//volumeSet/item') do |elem|
      volumes << parse_volume(elem)
    end
    return volumes
  end

  def attach_volume(volume_id, instance_id, device)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'AttachVolume',
      'VolumeId' => volume_id,
      'InstanceId' => instance_id,
      'Device' => device
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)
    res = {}
    res[:volume_id] = xml_doc.elements['//volumeId'].text
    res[:instance_id] = xml_doc.elements['//instanceId'].text
    res[:device] = xml_doc.elements['//device'].text
    res[:status] = xml_doc.elements['//status'].text
    res
  end

  def detach_volume(volume_id, instance_id = nil, device = nil, force = nil)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DetachVolume',
      'VolumeId' => volume_id,
      'InstanceId' => instance_id,
      'Device' => device,
      'Force' => force
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)
    res = {}
    res[:volume_id] = xml_doc.elements['//volumeId'].text
    res[:instance_id] = xml_doc.elements['//instanceId'].text
    res[:device] = xml_doc.elements['//device'].text
    res[:status] = xml_doc.elements['//status'].text
    res[:attach_time] = xml_doc.elements['//attachTime'].text
    res
  end

  def create_snapshot(volume_id)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'CreateSnapshot',
      'VolumeId' => volume_id
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)
    res = {}
    res[:snapshot_id] = xml_doc.elements['//snapshotId'].text
    res[:volume_id] = xml_doc.elements['//volumeId'].text
    res[:status] = xml_doc.elements['//status'].text
    res[:start_time] = xml_doc.elements['//startTime'].text
    res[:progress] = xml_doc.elements['//progress'].text
    res
  end

  def delete_snapshot(snapshot_id)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DeleteSnapshot',
      'SnapshotId' => snapshot_id
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)
    return xml_doc.elements['//return'].text == 'true'
  end

  def describe_snapshots(*snapshot_ids)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DescribeSnapshots',
      },{
      'SnapshotId' => snapshot_ids
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)
    xml_doc = REXML::Document.new(response.body)
    snapshots = []
    xml_doc.elements.each('//snapshotSet/item') do |elem|
      snapshots << {
      :snapshot_id => elem.elements['snapshotId'].text,
      :volume_id => elem.elements['volumeId'].text,
      :status => elem.elements['status'].text,
      :start_time => elem.elements['startTime'].text,
      :progress =>  elem.elements['progress'].text    
      }
    end
    return snapshots
  end

end
