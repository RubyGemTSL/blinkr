require 'uri'
require 'blinkr/error'
require 'blinkr/http_utils'

module Blinkr
  module Extensions
    # This class is used to collect and analyze links that are present on the page,
    # raise errors if links are broken, missing from sitemap, as well as user-configured errors/warnings.
    class Links
      include Blinkr::HttpUtils

      def initialize(config)
        @config = config
        @collected_links = {}
        @logger = Blinkr.logger
        @cached = {}
        @robots_txt_cache = {}
        @disallowed = []
      end

      def collect(page)
        page.body.css('a[href]').each do |a|
          attr = a.attribute('href')
          (page.response.request.url[-1, 1] == '/') ?
              src = page.response.request.url :
              src = page.response.request.url + '/'
          url = attr.value
          next if @config.skipped?(url)
          url = sanitize(url, src)
          unless url.nil?
            @collected_links[url] ||= []
            @collected_links[url] << {page: page, line: attr.line, snippet: attr.parent.to_s}
          end
        end
        @links = get_links(@collected_links)
      end

      def analyze(browser)
        unless @links.nil?
          @logger.info("Found #{@links.size} links".yellow)
          warn_incorrect_env(@links) unless @config.environments.empty?
          check_links(browser, @links)
        end
      end

      private

      def warn_incorrect_env(links)
        links.each do |url, locations|
          next unless @config.environments.is_a?(Array)
          @config.environments.each do |env|
            next unless url.to_s.include?(env)
            locations.each do |location|
              location[:page].errors << Blinkr::Error.new(severity: :warning,
                                                          category: 'Incorrect Environment',
                                                          type: '<a href=""> target is incorrect environment',
                                                          url: url.to_s,
                                                          title: "#{url} (line #{location[:line]})",
                                                          code: nil,
                                                          message: 'Incorrect Environment',
                                                          snippet: location[:snippet],
                                                          icon: 'fa-bookmark-o')
            end
          end
        end
      end

      def is_url?(url)
        true if url =~ /^#{URI.regexp(%w[http https])}$/
      end

      def get_links(links)
        if @config.ignore_external
          links.select { |k| k.start_with? @config.base_url }
        elsif @config.ignore_internal
          links.reject { |k| k.start_with? @config.base_url }
        else
          links
        end
      end

      def check_links(browser, links)
        processed = 0
        @logger.info("Checking #{links.length} links".yellow)
        Parallel.each(links, in_threads: (Parallel.processor_count * 2)) do |url, metadata|
          unless disallowed?(url)
            next if @config.skipped?(url)
            if @cached.has_key?(url.chomp('/'))
              @logger.info("Loaded #{url} from cache".green) if @config.verbose
              res = @cached["#{url.chomp('/')}"][:response]
            else
              unless @last_checked.nil? || @last_checked.include?(@config[:base_url])
                url_base = get_base(url)
                if @last_checked.include?(url_base)
                  timestamp = Time.now - @last_checked_timestamp
                  respect_robots_txt(url_base)
                  if timestamp < @delay
                    @logger.info("Respecting the website robots.txt Crawl-delay, waiting for #{@delay - timestamp} second(s)") if @config.verbose
                    sleep(@delay - timestamp)
                  end
                end
              end
              res = browser.process(url, @config.max_retrys)
              @cached["#{url.chomp('/')}"] = {response: res}
              @last_checked = get_base(url)
              @last_checked_timestamp = Time.now
            end
          end

          if res == SocketError
            resp_code = 503
            message = 'Site can’t be reached'
          elsif res == RestClient::Exceptions::Timeout || res == RestClient::Exceptions::OpenTimeout
            resp_code = 404
            message = 'Not Found'
          else
            (res.is_a? RestClient::Response) ? response = res : response = res.response
            resp_code = response.code.to_i
            message = res.message.gsub!(/\d+ /, '') if resp_code > 400 || resp_code == 0
          end
          metadata.each do |src|
            src[:page].errors << Blinkr::Error.new(severity: :danger,
                                                   category: 'Broken link',
                                                   type: '<a href=""> target cannot be loaded',
                                                   url: url, title: "#{url} (line #{src[:line]})",
                                                   code: resp_code, message: message,
                                                   detail: nil, snippet: src[:snippet],
                                                   icon: 'fa-bookmark-o')

          end if resp_code > 400 || resp_code == 0
          processed += 1
          @logger.info("Processed #{processed} of #{links.size}".yellow) if @config.verbose
        end
      end

      def respect_robots_txt(uri)
        @delay = 0
        begin
          unless @robots_txt_cache.has_key?(uri)
            robots = URI.join(uri.to_s, "/robots.txt").open
            @robots_txt_cache["#{uri}"] = {response: robots}
          end
          @robots_txt_cache["#{uri}"][:response].each do |line|
            next if line =~ /^\s*(#.*|$)/
            arr = line.split(":")
            key = arr.shift
            value = arr.join(":").strip
            value.strip!
            @delay = value.to_i if key.downcase == 'crawl-delay'
            @disallowed = value if key.downcase == 'disallow'
          end
        rescue => error
          unless error.message.include?('404')
            @logger.warn("#{error} when accessing robots.txt for #{uri}") if @config.verbose
          end
        end
      end

      def get_base(url)
        uri = URI.parse(url)
        "#{uri.scheme}://#{uri.host}"
      end

      def disallowed?(uri)
        @disallowed.include?(uri)
      end
    end
  end
end
