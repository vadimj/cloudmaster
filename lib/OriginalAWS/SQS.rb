# Sample Ruby code for the O'Reilly book "Programming Amazon Web
# Services" by James Murty.
#
# This code was written for Ruby version 1.8.6 or greater.
#
# The SQS module implements the Query API of the Amazon Simple Queue
# Service.
require 'AWS'
require 'rubygems'
require 'json'

class SQS
	include AWS # Include the AWS module as a mixin

	ENDPOINT_URI = URI.parse("https://queue.amazonaws.com/")
	API_VERSION = '2009-02-01'
	SIGNATURE_VERSION = '2'

	HTTP_METHOD = 'POST' # 'GET'

	def get_queue_url(queue_name)
		list_queues(queue_name).first
	end

	def list_queues(queue_name_prefix=nil)
		parameters = build_query_params(API_VERSION, SIGNATURE_VERSION,
			{
				'Action' => 'ListQueues',
				'QueueNamePrefix' => queue_name_prefix
			}
		)

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
		parameters = build_query_params(API_VERSION, SIGNATURE_VERSION, {
			'Action' => 'GetQueueAttributes',
			'AttributeName' => [ attribute ]
		})

		response = do_query(HTTP_METHOD, URI.parse(queue_url), parameters)

		attributes = {}
		xml_doc = REXML::Document.new(response.body)

		xml_doc.elements.each('//Attribute') do |att|
			name = att.elements['Name'].text
			# All currently supported attributes have integer values
			if (name == 'Policy')
				value = JSON.parse(att.elements['Value'].text)
			else
				value = att.elements['Value'].text.to_i
			end

			attributes[name] = value
		end

		return attributes[attribute] if attribute.downcase != 'all'
		return attributes
	end

	def set_queue_attribute(queue_url, value, attribute='VisibilityTimeout')
		set_queue_attributes(queue_url, { attribute => value })
	end

	def set_queue_attributes(queue_url, attributes)
		attr_count = 1
		attributes.replace(
			attributes.inject({'Action' => 'SetQueueAttributes'}) do |hash, (attribute,value)|
				hash["Attribute.#{attr_count}.Name"] = attribute
				hash["Attribute.#{attr_count}.Value"] = (attribute.match(/policy/i) && attribute.index('{') ? CGI.escape(value) : value)
				attr_count += 1
				hash
			end
		)

		parameters = build_query_params(API_VERSION, SIGNATURE_VERSION, attributes)
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

	def receive_new_messages(msgs, queue_url, max_count=1)
		new_msgs = receive_messages(queue_url, max_count)
		new_msgs.each do |new|
			msgs << new unless msgs.find{|old| old[:id] == new[:id]}
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

	def get_permissions(queue_url)
		policy = get_queue_attributes(queue_url, 'Policy')
		return [] if policy.nil? or not policy.is_a?(Hash)
		return policy['Statement']
	end

	def get_permissions_by_principal(queue_url)
		statements = get_permissions(queue_url)
		principals = statements.collect { |h| h['Principal']['AWS'] }.join(',').split(',')

		perms = {}
		principals.each do |p| perms[p.to_s] = get_account_permissions(queue_url, p); end

		return perms
	end

	def get_permission_labels(queue_url, account_id)
		policy = get_account_permissions(queue_url, account_id)
		(policy.is_a?(Array) ? policy : [ policy ]).map { |h| h['Sid'] }
	end

	def get_account_permissions(queue_url, accounts)
		policy = get_queue_attributes(queue_url, 'Policy')
		return  [] if policy.nil? or not policy.is_a?(Hash)

		accounts = [ accounts ] unless accounts.is_a? Array

		policy['Statement'].inject([]) { |array,stmt|
			account = stmt['Principal']['AWS']
			accounts.each do |id|
				array << stmt if account.include? id or account == '*'
			end
			array
		}
	end

	# Permissions is an array of [user-id, action, ... ] pairs.
	def add_permission(queue_url, label, permissions)
		perms = (permissions.is_a?(Hash) ? permissions : Hash[*permissions] )
		add_permissions(queue_url, label, perms)
	end

	def add_account_permission(queue_url, account_id, action)
		action = '*' if action =~ /all/i
		label = "#{account_id.to_s}_#{(action == '*' ? 'All' : action.capitalize)}"
		add_permissions(queue_url, label, { account_id => action })
	end

	# @param  String queue_url  URL of queue to set permisions on
	# @vparam Hash permissions  Hash of { AccountID => Action } values
	#
	# This is a destructive operation, removing any previous labels for
	def add_permissions(queue_url, label, permissions)
		attr_count = 1
		permissions.replace(
			permissions.inject({'Action' => 'AddPermission', 'Label' => label}) do |hash, (account_id,action)|
				labels = get_permission_labels(queue_url, account_id)

				action = '*' if action =~ /all/i

				unless labels.empty?
					# if there are already security labels for this account, and we are now setting
					# action to 'All', remove the previous labels and just set a simple 'All' label
					if (action == '*')
						remove_all_account_permissions(queue_url, account_id)
					elsif labels.include? account_id.to_s + '_All'
						# otherwise, if there is an 'All' policy, and we are setting a more specific policy
						# then remove the all, and substitute it with the more granular policy
						remove_account_permission(queue_url, account_id, 'All')
					end
				end

				hash["AWSAccountId.#{attr_count}"] = account_id
				hash["ActionName.#{attr_count}"] = (action.match(/^all$/i) ? '*' : action)
				attr_count += 1
				hash
			end
		)

		parameters = build_query_params(API_VERSION, SIGNATURE_VERSION, permissions)
		response = do_query(HTTP_METHOD, URI.parse(queue_url), parameters)
		return true
	end

	def remove_permission(queue_url, label)
		parameters = build_query_params(API_VERSION, SIGNATURE_VERSION, {
			'Action' => 'RemovePermission',
			'Label' => label
		})
		response = do_query(HTTP_METHOD, URI.parse(queue_url), parameters)
		return true
	end

	def remove_all_account_permissions(queue_url, account_id)
		get_permission_labels(queue_url, account_id).each do |label|
			remove_permission(queue_url, label)
		end
	end

	def remove_account_permission(queue_url, account_id, action)
		remove_permission(queue_url, "#{account_id.to_s}_#{action.capitalize}")
	end

end
