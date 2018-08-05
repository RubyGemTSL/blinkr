require 'typhoeus'
require 'blinkr/cache'
require 'blinkr/http_utils'
require 'net/http'
require 'logger'

module Blinkr
  class TyphoeusWrapper
    include HttpUtils

    attr_reader :count, :hydra

    def initialize(config, context)
      @config = config
      Typhoeus::Config.cache = Blinkr::Cache.new
      @hydra = Typhoeus::Hydra.new(maxconnects: (30),
                                   max_total_connections: (30),
                                   pipelining: false,
                                   max_concurrency: (30))
      Ethon::Curl.set_option(:max_host_connections, 5, @hydra.multi.handle, :multi)
      @count = 0
      @context = context
      @logger = Blinkr.logger
    end

    def process_all(urls, limit, opts = {}, &block)
      urls.each do |url|
        process url, limit, opts, &block
      end
      @hydra.run
    end

    def process(url, limit, opts = {}, &block)
      _process(url, limit, limit, opts, &block)
    end

    def debug(url)
      process(url, @config.max_retrys) do |resp|
        puts '++++++++++'
        puts '\nRequest'
        puts '======='
        puts "Method: #{resp.request.options[:method]}"
        puts "Max redirects: #{resp.request.options[:maxredirs]}"
        puts "Follow location header: #{resp.request.options[:followlocation]}"
        puts "Timeout (s): #{resp.request.options[:timeout] || 'none'}"
        puts "Connection timeout (s): #{resp.request.options[:connecttimeout] || 'none'}"
        puts '\nHeaders'
        puts '-------'
        unless resp.request.options[:headers].nil?
          resp.request.options[:headers].each do |name, value|
            puts "#{name}: #{value}"
          end
        end
        puts '\nResponse'
        puts '========'
        puts "Status Code: #{resp.code}"
        @status_code = resp.code
        puts "Status Message: #{resp.status_message}"
        @status_msg = resp.status_message
        puts "Message: #{resp.return_message}" unless resp.return_message.nil? || resp.return_message == 'No error'
        puts '\nHeaders'
        puts '-------'
        puts resp.response_headers
      end
      @hydra.run
    end

    def name
      'typhoeus'
    end

    private

    def _process(url, limit, max, opts = {}, &block)
      unless @config.skipped? url
        req = Typhoeus::Request.new(url,
                                    opts.merge(followlocation: true, timeout: 60,
                                               cookiefile: '_tmp/cookies', cookiejar: '_tmp/cookies',
                                               connecttimeout: 30, maxredirs: 3, ssl_verifypeer: false)
                                   )
        req.on_complete do |resp|
          if retry? resp
            if resp.code.to_i == 0
              @logger.info("Response code of '0', using net/http for #{url}")
              response = nil

              begin
                uri = URI.parse(url)
                http_response = Net::HTTP.get_response(uri)
                response = Typhoeus::Response.new(code: http_response.code, status_message: http_response.message,
                                                  mock: true)
              rescue
                response = Typhoeus::Response.new(code: 410, status_message: 'Could not reach the resource',
                                                  mock: true)
              end

              response.request = Typhoeus::Request.new(url, ssl_verifypeer: false)
              Typhoeus.stub(url).and_return(response)
              block.call(response, nil, nil)
              next
            end

            if limit > 1
              @logger.info("Loading #{url} via typhoeus (attempt #{max - limit + 2} of #{max})".yellow)
              _process(url, limit - 1, max, &Proc.new)
            else
              @logger.info("Loading #{url} via typhoeus failed".red)
              response = Typhoeus::Response.new(code: 0, status_message: "Server timed out after #{max} retries",
                                                mock: true)
              response.request = Typhoeus::Request.new(url, ssl_verifypeer: false)
              Typhoeus.stub(url).and_return(response)
              block.call(response, nil, nil)
            end
          else
            block.call(resp, nil, nil)
          end
        end
        @hydra.queue req
        @count += 1
      end
    end
  end
end
