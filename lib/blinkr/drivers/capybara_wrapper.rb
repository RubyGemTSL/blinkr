require 'parallel'
require 'open3'
require 'webmock'

module Blinkr
  class CapybaraWrapper
    include WebMock::API
    WebMock.enable!
    WebMock.allow_net_connect!

    PAGE = File.expand_path('page.rb', File.dirname(__FILE__))

    attr_reader :count

    def initialize(config, context)
      @config = config
      @context = context
      @count = 0
      @logger = Blinkr.logger
      @robots_txt_cache = {}
      @disallowed = []
    end

    def process_all(urls, limit, opts = {}, &block)
      Parallel.each(urls, in_threads: (@config.threads || Parallel.processor_count * 2)) do |url|
        process(url, limit, opts, &block)
      end
    end

    def process(url, limit, opts = {}, &block)
      _process(url, limit, limit, opts, &block)
    end

    def command
      "ruby #{PAGE} "
    end

    private

    def _process(url, limit, max, opts = {}, &block)
      raise "limit must be set. url: #{url}, limit: #{limit}, max: #{max}" if limit.nil?
      unless @config.skipped?(url) || disallowed?(url)
        output, status = Open3.capture2(command + "#{url} #{$remote}")
        if status == 0
          json = JSON.parse(output)
          stub_url(200, json['content'], url)
          response = get(url)
          block.call(response, json['javascriptErrors'])
        else
          if limit > 1
            @logger.info("Loading #{url} via chrome (attempt #{max - limit + 2} of #{max})".yellow)
            _process(url, limit - 1, max, &block)
          else
            @logger.info("Loading #{url} via chrome failed".red)
            stub_url(0, "Server timed out after #{max} retries", url)
            response = get(url)
            block.call(response, nil, nil)
          end
        end
        @count += 1
      end
    end

    def stub_url(status, body, url)
      stub_request(:get, url).
          with(headers: {
              'Accept' => '*/*'
          }).
          to_return(status: status, body: body, headers: {})
    end

    def get(url)
      begin
        RestClient::Request.execute(method: :get, url: url, max_redirects: 6, timeout: 30, verify_ssl: false)
      rescue RestClient::ExceptionWithResponse => err
        err.response
      end
    end

    def disallowed?(uri)
      get_robots_txt(uri)
      uri = URI.parse(uri)
      @disallowed.any? { |url| uri.path.include?(url) }
    end

    def get_robots_txt(uri)
      begin
        unless @robots_txt_cache.has_key?(uri)
          robots = URI.join(uri.to_s, "/robots.txt").open
          @robots_txt_cache["#{uri}"] = { response: robots }
        end
        @robots_txt_cache["#{uri}"][:response].each do |line|
          next if line =~ /^\s*(#.*|$)/
          arr = line.split(":")
          key = arr.shift
          value = arr.join(":").strip
          value.strip!
          @disallowed << value if key.downcase == 'disallow'
        end
      rescue => error
        unless error.message.include?('404')
          @logger.warn("#{error} when accessing robots.txt for #{uri}") if @config.verbose
        end
      end
    end
  end
end
