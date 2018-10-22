require 'rest-client'

module Blinkr
  class RestClientWrapper

    def initialize(config, context)
      @config = config
      @context = context
      @count = 0
      @logger = Blinkr.logger
    end

    def process(url, limit, opts = {}, &block)
      _process(url, limit, limit, opts, &block)
    end

    private

    def _process(url, limit, max, opts = {}, &block)
      raise "limit must be set. url: #{url}, limit: #{limit}, max: #{max}" if limit.nil?
      retries = 0
      unless @config.skipped?(url)
        begin
           RestClient::Request.execute(method: :get, url: url, max_redirects: 6, timeout: 30, verify_ssl: false)
        rescue RestClient::ExceptionWithResponse => result
          if retries < max
            retries += 1
            @logger.info("Loading #{url} (attempt #{retries} of #{max})".yellow) if @config.verbose
            retry
          else
            @logger.info("Loading #{url} failed".red) if @config.verbose
            return result
          end
        end
      end
    end

    def get(url)
      begin
        RestClient::Request.execute(method: :get, url: url, max_redirects: 6, timeout: 30, verify_ssl: false)
      rescue RestClient::ExceptionWithResponse => err
        err.response
      end
    end
  end
end
