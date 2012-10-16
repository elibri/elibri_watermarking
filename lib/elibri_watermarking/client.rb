require 'net/http'
require 'net/https'
require 'uri'
require 'digest/md5'
require 'base64'
require 'cgi'
require 'openssl'
require 'json'

module ElibriWatermarking
  class Client
    
    attr_accessor :token, :secret, :url
    
    def initialize(token, secret, url='https://elibri.com.pl/watermarking')
      self.token = token
      self.secret = secret
      self.url = url
    end
    
    def watermark(ident, formats, visible_watermark, title_postfix, args={})
      supplier = args[:supplier]
      client_symbol = args[:client_symbol]
      customer_ip = args[:customer_ip]
      ssl = args[:ssl]
      ssl = true if ssl.nil?
      ident =~ /^[0-9]+$/ ? ident_type = 'isbn' : ident_type = 'record_reference'
      raise WrongFormats.new if formats.is_a?(String) && !formats =~ /^(epub|mobi|pdf|,)+$/
      raise WrongFormats.new if formats.is_a?(Array) && ((formats - ['epub','mobi','pdf']) != [] || (formats & ['epub','mobi','pdf']).count < 1)
      uri = URI(self.url + '/watermark')
      formats = formats.join(",") if formats.is_a?(Array)
      timestamp = Time.now.to_i
      sig = CGI.escape(Base64.encode64(OpenSSL::HMAC.digest('sha1', timestamp.to_s, self.secret)).strip) 
      data = {ident_type => ident, 'formats' => formats, 'visible_watermark' => visible_watermark,
        'title_postfix' => title_postfix, 'stamp' => timestamp, 'sig' => sig, 'token' => self.token,
        'client_symbol' => client_symbol}
      if supplier
        data.merge!(:supplier => supplier)
      end
      if customer_ip
        data.merge!(:customer_ip => customer_ip)
      end
      req = Net::HTTP::Post.new(uri.path)
      req.set_form_data(data)
      http = Net::HTTP.new(uri.host, uri.port)
      if ssl
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      res = http.start {|http| http.request(req) }
      return validate_response(res)
    end
    
    def deliver(trans_id, ssl=true)
      uri = URI(self.url + '/deliver')
      timestamp = Time.now.to_i
      sig = CGI.escape(Base64.encode64(OpenSSL::HMAC.digest('sha1', timestamp.to_s, self.secret)).strip) 
      data = {'stamp' => timestamp, 'sig' => sig, 'token' => self.token, 'trans_id' => trans_id}
      req = Net::HTTP::Post.new(uri.path)
      req.set_form_data(data)
      http = Net::HTTP.new(uri.host, uri.port)
      if ssl
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      res = http.start {|http| http.request(req) }
      return validate_response(res)
    end
    
    def retry(trans_id, ssl=true)
      uri = URI(self.url + '/retry')
      timestamp = Time.now.to_i
      sig = CGI.escape(Base64.encode64(OpenSSL::HMAC.digest('sha1', timestamp.to_s, self.secret)).strip) 
      data = {'stamp' => timestamp, 'sig' => sig, 'token' => self.token, 'trans_id' => trans_id}
      req = Net::HTTP::Post.new(uri.path)
      req.set_form_data(data)
      http = Net::HTTP.new(uri.host, uri.port)
      if ssl
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      res = http.start {|http| http.request(req) }
      return validate_response(res)
    end
    
    def available_files(ssl=true)
      uri = URI(self.url + '/available_files.json')
      timestamp = Time.now.to_i
      sig = CGI.escape(Base64.encode64(OpenSSL::HMAC.digest('sha1', timestamp.to_s, self.secret)).strip) 
      data = {'stamp' => timestamp, 'sig' => sig, 'token' => self.token}
      req = Net::HTTP::Get.new(uri.path)
      req.set_form_data(data)
      http = Net::HTTP.new(uri.host, uri.port)
      if ssl
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      res = http.start {|http| http.request(req) }
      return JSON.parse(validate_response(res))
    end
    
    def soon_available_files(ssl=true)
      uri = URI(self.url + '/soon_available_files.json')
      timestamp = Time.now.to_i
      sig = CGI.escape(Base64.encode64(OpenSSL::HMAC.digest('sha1', timestamp.to_s, self.secret)).strip) 
      data = {'stamp' => timestamp, 'sig' => sig, 'token' => self.token}
      req = Net::HTTP::Get.new(uri.path)
      req.set_form_data(data)
      http = Net::HTTP.new(uri.host, uri.port)
      if ssl
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      res = http.start {|http| http.request(req) }
      return JSON.parse(validate_response(res))
    end
    
    def check_suppliers(ident, ssl=true)
      ident =~ /^[0-9]+$/ ? ident_type = 'isbn' : ident_type = 'record_reference'
      uri = URI(self.url + '/check_suppliers')
      timestamp = Time.now.to_i
      sig = CGI.escape(Base64.encode64(OpenSSL::HMAC.digest('sha1', timestamp.to_s, self.secret)).strip) 
      data = {'stamp' => timestamp, 'sig' => sig, 'token' => self.token, ident_type => ident}
      req = Net::HTTP::Get.new(uri.path)
      req.set_form_data(data)
      http = Net::HTTP.new(uri.host, uri.port)
      if ssl
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      res = http.start {|http| http.request(req) }
      return validate_response(res).split(",").map { |x| x.to_i }
    end
    
    def get_supplier(id, ssl=true)
      uri = URI(self.url + '/get_supplier')
      timestamp = Time.now.to_i
      sig = CGI.escape(Base64.encode64(OpenSSL::HMAC.digest('sha1', timestamp.to_s, self.secret)).strip) 
      data = {'stamp' => timestamp, 'sig' => sig, 'token' => self.token, 'id' => id}
      req = Net::HTTP::Get.new(uri.path)
      req.set_form_data(data)
      http = Net::HTTP.new(uri.host, uri.port)
      if ssl
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      res = http.start {|http| http.request(req) }
      return validate_response(res)
    end
    
    def watermark_and_deliver(ident, formats, visible_watermark, title_postfix, args={})
      trans_id = watermark(ident, formats, visible_watermark, title_postfix, args)
      return trans_id if deliver(trans_id) == "OK"
    end
    
    protected
    
    def validate_response(res)
      case res.class.to_s
      when "Net::HTTPBadRequest"
        raise ParametersError.new(res.body)
      when "Net::HTTPUnauthorized"
        raise AuthenticationError.new(res.body)
      when "Net::HTTPForbidden"
        raise AuthorizationError.new(res.body)
      when "Net::HTTPInternalServerError"
        raise ServerException.new(res.body)
      when "Net::HTTPRequestTimeOut"
        raise RequestExpired.new(res.body)
      when "Net::HTTPOK"
        return res.body
      end
      return res.body
    end
  end
end
