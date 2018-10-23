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
            @collected_links[url] << { page: page, line: attr.line, snippet: attr.parent.to_s }
          end
        end
        @links = get_links(@collected_links)
      end

      def analyze(browser)
        @logger.info("Found #{@links.size} links".yellow)
        warn_incorrect_env(@links) unless @config.environments.empty?
        check_links(browser, @links)
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
        links.each do |url, metadata|
          if @cached.include?(url)
            @logger.info("Loaded #{url} from cache") if @config.verbose
            res = @cached[:"#{url}"][:response]
          else
            res = browser.process(url, @config.max_retrys)
          end
          (res.is_a? RestClient::Response) ? response = res : response = res.response
          resp_code = response.code.to_i
          if resp_code > 400 || resp_code == 0
            metadata.each do |src|
              src[:page].errors << Blinkr::Error.new(severity: :danger,
                                                     category: 'Broken link',
                                                     type: '<a href=""> target cannot be loaded',
                                                     url: url, title: "#{url} (line #{src[:line]})",
                                                     code: response.code.to_i, message: res.message,
                                                     detail: nil, snippet: src[:snippet],
                                                     icon: 'fa-bookmark-o') unless resp_code == 200

            end
          end
          processed += 1
          @cached["#{url}"] = {response: res}
          @logger.info("Processed #{processed} of #{links.size}".yellow)
        end
      end
    end
  end
end
