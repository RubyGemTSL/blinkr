require 'rest-client'
require 'webmock'

module Blinkr
  class RestClientWrapper
    include WebMock::API
    WebMock.enable!
    WebMock.allow_net_connect!

    attr_reader :count

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
      @logger.info("Checking #{url}")
      raise "limit must be set. url: #{url}, limit: #{limit}, max: #{max}" if limit.nil?
      retries = 0
      begin
        RestClient::Request.execute(method: :get, url: url, max_redirects: 6, timeout: 30, verify_ssl: false)
      rescue RestClient::ExceptionWithResponse, SocketError => result
        return result.class if result.class == SocketError
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

    def get(url)
      begin
        RestClient::Request.execute(method: :get, url: url, max_redirects: 6, timeout: 30, verify_ssl: false)
      rescue RestClient::ExceptionWithResponse => err
        err.response
      end
    end
  end

  def stub(status, body, url)
    stub_request(:get, url).
        with(headers: {
            'Accept' => '*/*'
        }).
        to_return(status: status, body: body, headers: {})
  end

  def foo(url)
    retries = 0
    begin
      RestClient::Request.execute(method: :get, url: url, max_redirects: 6, timeout: 30, verify_ssl: false)
    rescue RestClient::ExceptionWithResponse, SocketError => result
      if retries < 3
        stub(404, 'Not found', url) if result.class == SocketError
        retries += 1
        puts("Loading #{url} (attempt #{retries} of ")
        retry
      else
        puts("Loading #{url} failed")
        return result
      end
    end
  end
end
