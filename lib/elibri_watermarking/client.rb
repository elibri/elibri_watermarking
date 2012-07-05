require 'net/http'
require 'net/https'
require 'uri'
require 'digest/md5'

module ElibriWatermarking
  class Client
    
    attr_accessor :token, :secret, :url
    
    def initialize(token, secret, url='https://elibri.com.pl/watermarking')
      self.token = token
      self.secret = secret
      self.url = url
    end
    
    def watermark(ident, formats, visible_watermark, title_postfix)
      ident =~ /^[0-9]+$/ ? ident_type = 'isbn' : ident_type = 'record_reference'
      raise WrongFormats.new if formats.is_a?(String) && !formats =~ /^(epub|mobi|,)+$/
      raise WrongFormats.new if formats.is_a?(Array) && (formats != ['epub','mobi'] && formats != ['mobi','epub'] && formats != ['mobi'] && formats != ['epub'])
      uri = URI(self.url + '/watermark')
      formats = formats.join(",") if formats.is_a?(Array)
      timestamp = Time.now.to_i
      sig = Digest::MD5.hexdigest("#{self.secret}_#{timestamp}")    
      data = {ident_type => ident, 'formats' => formats, 'visible_watermark' => visible_watermark,
        'title_postfix' => title_postfix, 'stamp' => timestamp, 'sig' => sig, 'token' => self.token}
      req = Net::HTTP::Post.new(uri.path)
      req.set_form_data(data)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      res = http.start {|http| http.request(req) }
      return validate_response(res)
    end
    
    def deliver(trans_id)
      uri = URI(self.url + '/deliver')
      timestamp = Time.now.to_i
      sig = Digest::MD5.hexdigest("#{self.secret}_#{timestamp}")
      data = {'stamp' => timestamp, 'sig' => sig, 'token' => self.token, 'trans_id' => trans_id}
      req = Net::HTTP::Post.new(uri.path)
      req.set_form_data(data)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      res = http.start {|http| http.request(req) }
      return validate_response(res)
    end
    
    def retry(trans_id)
      uri = URI(self.url + '/retry')
      timestamp = Time.now.to_i
      sig = Digest::MD5.hexdigest("#{self.secret}_#{timestamp}")
      data = {'stamp' => timestamp, 'sig' => sig, 'token' => self.token, 'trans_id' => trans_id}
      req = Net::HTTP::Post.new(uri.path)
      req.set_form_data(data)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      res = http.start {|http| http.request(req) }
      return validate_response(res)
    end
    
    def watermark_and_deliver(ident, formats, visible_watermark, title_postfix)
      trans_id = watermark(ident, formats, visible_watermark, title_postfix)
      return trans_id if deliver(trans_id) == "OK"
    end
    
    protected
    
    def validate_response(res)
      case res.class.to_s
      when "Net::HTTPBadRequest"
        raise ParametersError.new
      when "Net::HTTPUnauthorized"
        raise AuthenticationError.new        
      when "Net::HTTPForbidden"
        raise AuthorizationError.new
      when "Net::HTTPInternalServerError"
        raise ServerException.new
      when "Net::HTTPOK"
        return res.body
      end
      return res.body
    end
  end
end
