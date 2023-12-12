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

    attr_accessor :token, :secret, :logger, :server

    def initialize(token, secret, server = nil)
      self.token = token
      self.secret = secret
      self.server = server || "https://www.elibri.com.pl"
    end

    def watermark(ident, formats:, visible_watermark:, client_symbol: nil, price: nil, promotion_id: nil, low_priority: false)
      if ident =~ /^[0-9]+$/ && ident.size == 13
        ident_type = 'isbn'
      else
        ident_type = 'record_reference'
      end
      raise WrongFormats.new if formats.is_a?(String) && !(formats =~ /^(epub|mobi|pdf|mp3_in_zip|mp3_in_lpf|,)+$/)
      raise WrongFormats.new if formats.is_a?(Array) && ((formats - ['epub','mobi','pdf','mp3_in_zip']) != [] || (formats & ['epub','mobi','pdf','mp3_in_zip']).count < 1)
      formats = formats.join(",") if formats.is_a?(Array)
      data = { ident_type => ident, formats: formats, visible_watermark: visible_watermark }
      data.merge!(client_symbol: client_symbol) if client_symbol
      data.merge!(price: price) if price
      data.merge!(promotion_id: promotion_id) if promotion_id
      data.merge!(low_priority: low_priority) if low_priority
      construct_url('watermark') do |uri|
        return get_response_from_server(uri, data, Net::HTTP::Post)
      end
    end

    def deliver(trans_id, low_priority: false)
      construct_url('deliver') do |uri|
        data = { trans_id: trans_id }
        data.merge!(low_priority: low_priority) if low_priority
        return get_response_from_server(uri, data, Net::HTTP::Post)
      end
    end

    def retry(trans_id, low_priority: false)
      construct_url('retry') do |uri|
        data = { trans_id: trans_id, delivery_form: delivery_form}
        data.merge!(:low_priority => low_priority) if low_priority
        return get_response_from_server(uri, data, Net::HTTP::Post)
      end
    end

    def available_files
      construct_url('available_files.json') do |uri|
        return JSON.parse(get_response_from_server(uri, {}, Net::HTTP::Get))
      end
    end

    def soon_available_files
      construct_url('soon_available_files.json') do |uri|
        return JSON.parse(get_response_from_server(uri, {}, Net::HTTP::Get))
      end
    end

    def soon_unavailable_files
      construct_url('soon_unavailable_files.json') do |uri|
        return JSON.parse(get_response_from_server(uri, {}, Net::HTTP::Get))
      end
    end

    def new_complaint(trans_id, reason)
      construct_url('/api_complaints') do |uri|
        return get_response_from_server(uri, {:trans_id => trans_id, :reason => reason}, Net::HTTP::Post)
      end
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

    def construct_url(action)
      if action[0] == "/"
        uri = URI("#{server}#{action}")
      else
        uri = URI("#{server}/transactional_api/#{action}")
      end
      logger.info("trying #{uri}") if logger
      begin
        yield uri
      rescue Timeout::Error, SystemCallError
        logger.error($!) if logger
      rescue ServerException
        logger.error($!) if logger
      end
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
      else
        raise ServerException.new(res.body)
      end
    end
  end
end
