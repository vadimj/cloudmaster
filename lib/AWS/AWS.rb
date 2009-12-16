$:.unshift(File.join(ENV['AWS_HOME'], "lib", "OriginalAWS"))
require 'OriginalAWS/AWS'
require 'uri'

#
# Extending the original AWS class to support Signatures Version 2
# The added functions are based on Perl library published by Amazon
# $Id: AWS.rb 15456 2009-05-20 04:28:59Z vadimj $
#

module AWS
    #
    # Computes RFC 2104-compliant HMAC signature for request parameters
    # Implements AWS Signature, as per following spec:
    #
    # If Signature Version is 0, it signs concatenated Action and Timestamp
    #
    # If Signature Version is 1, it performs the following:
    #
    # Sorts all  parameters (including SignatureVersion and excluding Signature,
    # the value of which is being created), ignoring case.
    #
    # Iterate over the sorted list and append the parameter name (in original case)
    # and then its value. It will not URL-encode the parameter values before
    # constructing this string. There are no separators.
    #
    def signParameters(parameters, key, uri = nil, algorithm = :HmacSHA1 )
        data = ""
        signatureVersion = parameters['SignatureVersion']

        case signatureVersion.to_i
			when 0:
				data = calculateStringToSignV0(parameters)
			when 1:
				data = calculateStringToSignV1(parameters)
			when 2:
				algorithm = parameters['SignatureMethod'] if parameters['SignatureMethod']
				parameters['SignatureMethod'] = algorithm.to_s
				data = calculateStringToSignV2(parameters, uri.is_a?(URI) ? uri : URI.parse(uri))
			else
				raise "Invalid Signature Version specified"
        end

        sign(data, key, algorithm)
    end

    def calculateStringToSignV0(parameters)
        parameters['Action']+parameters['Timestamp']
    end

    def calculateStringToSignV1(parameters)
        parameters.sort {|x,y| x[0].downcase <=> y[0].downcase}.to_s
    end

    def calculateStringToSignV2(parameters, endpoint)
        data = "POST\n"
        data << endpoint.host.downcase + "\n"
        data << endpoint.request_uri + "\n"

		# Sort, and encode parameters into a canonical string.
		sorted_params = parameters.sort {|x,y| x[0] <=> y[0]}
		encoded_params = sorted_params.collect do |p|
			encoded = (CGI::escape(p[0].to_s) + "=" + CGI::escape(p[1].to_s))
			# Ensure spaces are encoded as '%20', not '+'
			encoded.gsub('+', '%20')
		end
		data << encoded_params.join("&")

        return data
    end

    #
    # Computes RFC 2104-compliant HMAC signature.
    #
    def sign(data, key, algorithm)
		case algorithm
			when :HmacSHA1
				digest_generator = OpenSSL::Digest::Digest.new('sha1')
			when :HmacSHA256
				digest_generator = OpenSSL::Digest::Digest.new('sha256')
			else
				raise "Non-supported signing method specified"
        end

        digest = OpenSSL::HMAC.digest(digest_generator, key, data)
        encode_base64(digest)
    end
end
