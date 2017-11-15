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
      end

      def collect(page)
        page.body.css('a[href]').each do |a|
          attr = a.attribute('href')
          src = page.response.effective_url
          url = attr.value
          next if @config.skipped?(url) || !is_url?(url)
          url = sanitize(url, src)
          unless url.nil?
            @collected_links[url] ||= []
            @collected_links[url] << { page: page, line: attr.line, snippet: attr.parent.to_s }
          end
        end
        @links = get_links(@collected_links)
      end

      def analyze(context, browser)
        @logger.info("Found #{@links.size} links".yellow)
        unless @config.ignore_internal
          internal_links = @links.select { |k| k.start_with? @config.base_url }
          internal_links.each do |url, _|
            link = fixup_link(url)
            next if context.pages.keys.include?(link.to_s) || context.pages.keys.include?("#{link}/")
          end
        end
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
                                                          detail: 'Checked with Typheous',
                                                          snippet: location[:snippet],
                                                          icon: 'fa-bookmark-o')
            end
          end
        end
      end

      def fixup_link(url)
        link = URI.parse(url)
        link.fragment = nil
        link.query = nil
        link.path = link.path.gsub(%r{/\/+/}, '/') if link.path
        url = URI.parse(@config.base_url).merge(link).to_s
        url.chomp('/') if url[-1, 1] == '/'
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
          browser.process(url, @config.max_retrys, method: :get, followlocation: true, timeout: 60, cookiefile: '_tmp/cookies',
                          cookiejar: '_tmp/cookies', connecttimeout: 30, maxredirs: 3) do |resp|
            @logger.info("Loaded #{url} via #{browser.name} #{'(cached)' if resp.cached?}".green) if @config.verbose

            resp_code = resp.code.to_i
            if resp_code > 400 || resp_code == 0
              response = resp
              detail = nil
              if response.status_message.nil?
                message = response.return_message
              else
                message = response.status_message
                detail = response.return_message unless resp.return_message == 'No error'
              end
              severity = :danger
              metadata.each do |src|
                next if response.success?
                src[:page].errors << Blinkr::Error.new(severity: severity,
                                                       category: 'Broken link',
                                                       type: '<a href=""> target cannot be loaded',
                                                       url: url, title: "#{url} (line #{src[:line]})",
                                                       code: response.code.to_i, message: message,
                                                       detail: detail, snippet: src[:snippet],
                                                       icon: 'fa-bookmark-o')
              end
            end
            processed += 1
            @logger.info("Processed #{processed} of #{links.size}".yellow) if @config.verbose
          end
        end
        browser.hydra.run if browser.is_a? Blinkr::TyphoeusWrapper
      end
    end
  end
end
