require 'typhoeus'
require 'ostruct'
require 'tempfile'
require 'blinkr/http_utils'
require 'blinkr/cache'
require 'parallel'
require 'open3'

module Blinkr
  class PhantomJSWrapper
    include HttpUtils

    SNAP_JS = File.expand_path('page.js', File.dirname(__FILE__))

    attr_reader :count

    def initialize(config, context)
      @config = config
      @context = context
      @count = 0
      @cache = Blinkr::Cache.new
      @logger = Blinkr.logger
    end

    def process_all(urls, limit, opts = {}, &block)
      Parallel.each(urls, in_threads: (@config.threads || Parallel.processor_count * 2)) do |url|
        process(url, limit, opts, &block)
      end
    end

    def process(url, limit, opts = {}, &block)
      _process(url, limit, limit, opts, &block)
    end

    def name
      'phantomjs'
    end

    def command
      'phantomjs --ignore-ssl-errors=yes --ssl-protocol=any'
    end

    private


    def _process(url, limit, max, opts = {}, &block)
      raise "limit must be set. url: #{url}, limit: #{limit}, max: #{max}" if limit.nil?
      unless @config.skipped?(url)
        # Try and sidestep any unnecessary requests by checking the cache
        request = Typhoeus::Request.new(url)
        if @cache.get(request)
          return block.call(response, @cache.get("#{url}-javascriptErrors"))
        end

        output, status = Open3.capture2("#{command} #{SNAP_JS} #{url}")

        if status == 0
          json = JSON.parse(output)
          response = Typhoeus::Response.new(code: 200, body: json['content'], effective_url: json['url'],
                                            mock: true)
          response.request = Typhoeus::Request.new(url)
          Typhoeus.stub(url).and_return(response)
          @cache.set(response.request, response)
          @cache.set("#{url}-javascriptErrors", json['javascriptErrors'])
          block.call(response, json['javascriptErrors'])
        else
          if limit > 1
            @logger.info("Loading #{url} via phantomjs (attempt #{max - limit + 2} of #{max})".yellow)
            _process(url, limit - 1, max, &block)
          else
            @logger.info("Loading #{url} via phantomjs failed".red)
            response = Typhoeus::Response.new(code: 0, status_message: "Server timed out after #{max} retries",
                                              mock: true)
            response.request = Typhoeus::Request.new(url)
            Typhoeus.stub(url).and_return(response)
            @cache.set(response.request, response)
            block.call(response, nil, nil)
          end
        end
        @count += 1
      end
    end
  end
end
