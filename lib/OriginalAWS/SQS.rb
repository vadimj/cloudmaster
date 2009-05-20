# Sample Ruby code for the O'Reilly book "Programming Amazon Web
# Services" by James Murty.
#
# This code was written for Ruby version 1.8.6 or greater.
#
# The SQS module implements the Query API of the Amazon Simple Queue
# Service.
require 'AWS'

class SQS
  include AWS # Include the AWS module as a mixin

  ENDPOINT_URI = URI.parse("https://queue.amazonaws.com/")
  API_VERSION = '2009-02-01'
  SIGNATURE_VERSION = '2'

  HTTP_METHOD = 'POST' # 'GET'


  def list_queues(queue_name_prefix=nil)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'ListQueues',
      'QueueNamePrefix' => queue_name_prefix
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)

    queue_names = []
    xml_doc = REXML::Document.new(response.body)

    xml_doc.elements.each('//QueueUrl') do |queue_url|
      queue_names << queue_url.text
    end

    return queue_names
  end

  def create_queue(queue_name, visibility_timeout_secs=nil)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'CreateQueue',
      'QueueName' => queue_name,
      'DefaultVisibilityTimeout' => visibility_timeout_secs
      })

    response = do_query(HTTP_METHOD, ENDPOINT_URI, parameters)

    xml_doc = REXML::Document.new(response.body)
    return xml_doc.elements['//QueueUrl'].text
  end

  def delete_queue(queue_url, force_deletion=nil)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DeleteQueue'
      })

    response = do_query(HTTP_METHOD, URI.parse(queue_url), parameters)

    return true
  end

  def get_queue_attributes(queue_url, attribute='All')
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'GetQueueAttributes',
      },
      {
      'AttributeName' => [attribute]
      })
    response = do_query(HTTP_METHOD, URI.parse(queue_url), parameters)

    attributes = {}
    xml_doc = REXML::Document.new(response.body)

    xml_doc.elements.each('//Attribute') do |att|
      name = att.elements['Name'].text
      value = att.elements['Value'].text

      attributes[name] = value
    end

    return attributes
  end

  def set_queue_attribute(queue_url, value, attribute='VisibilityTimeout')
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'SetQueueAttributes',
      'Attribute.Name' => attribute,
      'Attribute.Value' => value
      })

    response = do_query(HTTP_METHOD, URI.parse(queue_url), parameters)
    return true
  end

  def send_message(queue_url, message_body, encode=false)
    message_body = encode_base64(message_body) if encode

    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'SendMessage',
      'MessageBody' => message_body
      })

    response = do_query(HTTP_METHOD, URI.parse(queue_url), parameters)

    xml_doc = REXML::Document.new(response.body)
    return xml_doc.elements['//MessageId'].text
  end

  def receive_messages(queue_url, maximum=1, visibility_timeout=nil, 
    attributes = [])
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'ReceiveMessage',
      'MaxNumberOfMessages' => maximum,
      'VisibilityTimeout' => visibility_timeout
      },
      {
      'AttributeName' => attributes
      })

    response = do_query(HTTP_METHOD, URI.parse(queue_url), parameters)

    msgs = []

    xml_doc = REXML::Document.new(response.body)

    xml_doc.elements.each('//Message') do |msg|
      returned_attributes = {}

      msg.elements.each('Attribute') do |att|
        name = att.elements['Name'].text
        value = att.elements['Value'].text
        returned_attributes[name] = value
      end

      msgs << {
        :id => msg.elements['MessageId'].text,
        :receipt_handle => msg.elements['ReceiptHandle'].text,
        :body => msg.elements['Body'].text,
        :attributes => returned_attributes
      }

    end

    return msgs
  end

  def delete_message(queue_url, receipt_handle)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'DeleteMessage',
      'ReceiptHandle' => receipt_handle
      })

    response = do_query(HTTP_METHOD, URI.parse(queue_url), parameters)

    return true
  end

  def change_message_visibility(queue_url, message_id, visibility_timeout=0)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'ChangeMessageVisibility',
      'MessageId' => message_id,
      'VisibilityTimeout' => visibility_timeout
      })

    response = do_query(HTTP_METHOD, URI.parse(queue_url), parameters)

    return true
  end

  # Permissions is an array of [user-id, action] pairs.
  def add_permission(queue_url, label, permissions)
    grantee = []
    action = []
    permissions.each do |perm|
      grantee << perm[0]
      action << perm[1]
    end
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'AddPermission',
      'Label' => label
      },
      {
      'AWSAccountId' => grantee,
      'ActionName' => action
      })

    response = do_query(HTTP_METHOD, URI.parse(queue_url), parameters)

    return true
  end

  def remove_permission(queue_url, label)
    parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
      {
      'Action' => 'RemovePermission',
      'Label' => label
      })

    response = do_query(HTTP_METHOD, URI.parse(queue_url), parameters)

    return true
  end

  def receive_new_messages(msgs, queue_url, max_count=1)
    new_msgs = receive_messages(queue_url, max_count)
    new_msgs.each do |new|
      msgs << new unless msgs.find{|old| old[:id] == new[:id]}
    end
    return msgs
  end

end
