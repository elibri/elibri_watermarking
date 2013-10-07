require 'net/http'
require 'net/https'
require 'net/dns'
require 'uri'
require 'digest/md5'
require 'base64'
require 'cgi'
require 'openssl'
require 'json'

module ElibriWatermarking
  class Client
    
    attr_accessor :token, :secret, :logger, :servers
    
    def initialize(token, secret, servers = nil)
      self.token = token
      self.secret = secret
      self.servers = servers
    end
    
    def watermark(ident, formats, visible_watermark, title_postfix, customer_ip, client_symbol = nil, supplier = nil, delivery_form = nil, price = nil, promotion_id = nil)
      if ident =~ /^[0-9]+$/ && ident.size == 13
        ident_type = 'isbn'
      else
        ident_type = 'record_reference'
      end
      raise WrongFormats.new if formats.is_a?(String) && !formats =~ /^(epub|mobi|pdf|mp3_in_zip|,)+$/
      raise WrongFormats.new if formats.is_a?(Array) && ((formats - ['epub','mobi','pdf','mp3_in_zip']) != [] || (formats & ['epub','mobi','pdf','mp3_in_zip']).count < 1)
      formats = formats.join(",") if formats.is_a?(Array)
      raise ParametersError.new if delivery_form && formats != 'mp3_in_zip'
      raise ParametersError.new if delivery_form && (delivery_form != 'mp3' && delivery_form != 'zip')
      data = {ident_type => ident, 'formats' => formats, 'visible_watermark' => visible_watermark,
              'title_postfix' => title_postfix, 'client_symbol' => client_symbol, 'delivery_form' => delivery_form}
      data.merge!(:supplier => supplier) if supplier
      data.merge!(:customer_ip => customer_ip) if customer_ip
      data.merge!(:price => price) if price
      data.merge!(:promotion_id => promotion_id) if promotion_id
      try_with_different_servers('watermark') do |uri|
        return get_response_from_server(uri, data, Net::HTTP::Post)
      end  
    end

    def deliver(trans_id)
      try_with_different_servers('deliver') do |uri|
        return get_response_from_server(uri, {'trans_id' =>  trans_id}, Net::HTTP::Post)
      end
    end

    def retry(trans_id, delivery_form = nil)
      try_with_different_servers('retry') do |uri|
        return get_response_from_server(uri, {'trans_id' =>  trans_id, 'delivery_form' => delivery_form}, Net::HTTP::Post)
      end
    end

    def available_files
      try_with_different_servers('available_files.json') do |uri|
        return JSON.parse(get_response_from_server(uri, {}, Net::HTTP::Get))
      end
    end

    def soon_available_files
      try_with_different_servers('soon_available_files.json') do |uri|
        return JSON.parse(get_response_from_server(uri, {}, Net::HTTP::Get))
      end
    end
    
    def soon_unavailable_files
      try_with_different_servers('soon_unavailable_files.json') do |uri|
        return JSON.parse(get_response_from_server(uri, {}, Net::HTTP::Get))
      end
    end

    def check_suppliers(ident)
      ident =~ /^[0-9]+$/ ? ident_type = 'isbn' : ident_type = 'record_reference'
      try_with_different_servers('check_suppliers') do |uri|
        return get_response_from_server(uri, { ident_type => ident}, Net::HTTP::Get).split(",").map { |x| x.to_i }
      end
    end

    def get_supplier(id)
      get_response_from_server(URI('https://www.elibri.com.pl/watermarking/get_supplier'), {:id => id}, Net::HTTP::Get)
      #to chyba moze byc tylko z glownego serwera?
    end
    
    def check_api
      try_with_different_servers('ver') do |uri|
        return get_response_from_server(uri, {}, Net::HTTP::Get)
      end
    end
    
    def new_complaint(trans_id, reason)
      get_response_from_server(URI('https://www.elibri.com.pl/api_complaints'), {:trans_id => trans_id, :reason => reason}, Net::HTTP::Post)
    end

    protected

    def get_response_from_server(uri, data, request_class)
      logger.info("doing #{uri}") if logger
      timestamp = Time.now.to_i.to_s
      data.merge!({'stamp' => timestamp, 'sig' => CGI.escape(Base64.encode64(OpenSSL::HMAC.digest('sha1', timestamp, self.secret)).strip), 'token' => self.token})
      req = request_class.new(uri.path)
      req.set_form_data(data)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      res = http.start {|http| http.request(req) }
      return validate_response(res)
    end

    def try_with_different_servers(action)
      txt_record = self.servers || Net::DNS::Resolver.start("transactional-servers.elibri.com.pl", Net::DNS::TXT).answer.first.txt
      servers = txt_record.split(",").sort_by { rand }.map(&:strip)
      servers.each do |server|
        uri = URI("https://#{server}.elibri.com.pl/watermarking/#{action}")
        logger.info("trying #{uri}") if logger
        begin
          yield uri
        rescue Timeout::Error, SystemCallError
          logger.error($!) if logger
        rescue ServerException
          logger.error($!) if logger
        end
      end
      raise NoWorkingServer.new("none of the servers #{servers.map { |s| "#{s}.elibri.com.pl" }.join(', ')} seems to work now")
    end

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
