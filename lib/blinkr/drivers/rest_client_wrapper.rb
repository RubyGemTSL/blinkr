require 'rest-client'

module Blinkr
  class RestClientWrapper
    attr_reader :count

    HEADERS = {
        'User-Agent': 'Blinkr broken-link checker',
        'Accept-Encoding': '*/*',
    }

    def initialize(config, context)
      @config = config
      @context = context
      @logger = Blinkr.logger
    end

    def process(url, limit, opts = {}, &block)
      _process(url, limit, limit, opts, &block)
    end

    private

    def _process(url, limit, max, opts = {}, &block)
      raise "limit must be set. url: #{url}, limit: #{limit}, max: #{max}" if limit.nil?
      retries = 0
      puts "!!!!!!!!!!!!!!!!!!!! #{url}" if url === 'http://tel:+18887334281'
      begin
        RestClient::Request.execute(
            method: :get,
            url: url,
            max_redirects: (@config.max_retrys || 3),
            timeout: 30,
            verify_ssl: false,
            headers: HEADERS
        )
      rescue RestClient::ExceptionWithResponse, SocketError => result
        return result.class if result.class == SocketError
        if retries < max
          retries += 1
          @logger.info("Loading #{url} (attempt #{retries} of #{max})".yellow) if @config.verbose
          retry
        else
          @logger.info("Loading #{url} failed".red) if @config.verbose
          (result.is_a?(RestClient::Exceptions::Timeout) || result.is_a?(RestClient::Exceptions::OpenTimeout)) ?
              response = result.class :
              response = result
          return response
        end
      end
    end

    def get(url)
      begin
        RestClient::Request.execute(
            method: :get,
            url: url,
            max_redirects: (@config.max_retrys || 3),
            timeout: 30,
            verify_ssl: false,
            headers: HEADERS
        )
      rescue RestClient::ExceptionWithResponse => err
        err.response
      end
    end
  end
end
