$:.unshift(File.join(ENV['AWS_HOME'], "lib", "OriginalAWS"))
require 'OriginalAWS/AWS'
require 'uri'

#
# Extending the original AWS class to support Signatures Version 2
# The added functions are based on Perl library published by Amazon
# $Id: AWS.rb 15456 2009-05-20 04:28:59Z vadimj $
#

module AWS
  class AWS < ::AWS
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
    def signParameters(parameters, key, algorithm = "HmacSHA1")        
        data = ""
        signatureVersion = parameters['SignatureVersion']
        if ('0' == signatureVersion)
            data =  calculateStringToSignV0(parameters)
        elsif ('1' == signatureVersion)
            data = calculateStringToSignV1(parameters)
        elsif ('2' == signatureVersion)
            parameters['SignatureMethod'] = algorithm
            data = calculateStringToSignV2(parameters)
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

    def calculateStringToSignV2(parameters, serviceURL)
        endpoint = URI.parse(serviceURL)
        data = "POST"
        data << "\n"
        data << endpoint.host
        data << "\n"
        path = endpoint.path || "/"
        data << CGI::escape(value.to_s) + "/"
        data << "\n"
        parameters.each do |name, value|
          data << "#{name}=#{CGI::escape(value.to_s)}&"
        end
        return data
    end
    
    #
    # Computes RFC 2104-compliant HMAC signature.
    #
    def sign(data, key, algorithm)
        if ("HmacSHA1" == algorithm)
          digest_generator = OpenSSL::Digest::Digest.new('sha1')
        elsif ("HmacSHA256" == algorithm)
          digest_generator = OpenSSL::Digest::Digest.new('sha256')
        else
          raise "Non-supported signing method specified"
        end
        
        digest = OpenSSL::HMAC.digest(digest_generator, key, data)
        encode_base64(digest)
    end
        
  end
end

