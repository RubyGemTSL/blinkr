require 'nokogiri'
require 'blinkr/drivers/capybara_wrapper'
require 'blinkr/drivers/rest_client_wrapper'
require 'blinkr/http_utils'
require 'blinkr/sitemap'
require 'blinkr/report'
require 'blinkr/formatter/default_logger'
require 'blinkr/extensions/links'
require 'blinkr/extensions/javascript'
require 'json'
require 'pathname'
require 'fileutils'
require 'ostruct'
require_relative '../../lib/blinkr/openstruct'

module Blinkr
  class Engine
    include HttpUtils

    def initialize(config)
      @config = config.validate
      @extensions = []
      @logger = Blinkr.logger
      load_pipeline
    end

    def run
      context = OpenStruct.new(pages: {})

      bulk_browser, browser = define_browser(context)
      page_count = 0
      urls = Sitemap.new(@config).sitemap_locations

      @logger.info("Fetching #{urls.size} pages from sitemap".yellow)
      browser.process_all(urls, @config.max_page_retrys) do |response, javascript_errors|
        url = response.request.url
        if response.code == 200
          @logger.info("Loaded page #{url}".green) if @config.verbose
          body = Nokogiri::HTML(response.body)
          page = OpenStruct.new(response: response,
                                body: body.freeze,
                                errors: ErrorArray.new(@config),
                                javascript_errors: javascript_errors || [])
          context.pages[url] = page
          collect(page)
          page_count += 1
        else
          @logger.warn("#{response.code} #{response.status_message} Unable to load page #{url} #{'(' + response.return_message + ')' unless response.return_message.nil?}".red)
        end
      end
      @logger.info("Loaded #{page_count} pages using #{@config.browser}.".green) if @config.verbose
      @logger.info('Analyzing pages'.yellow)
      analyze(bulk_browser)
      context.pages.reject! { |_, page| page.errors.empty? }
      context
    end

    def define_browser(context)
      bulk_browser = RestClientWrapper.new(@config, context)
      $remote = true if @config.remote
      js_browser = CapybaraWrapper.new(@config, context)
      [bulk_browser, js_browser]
    end

    def append(context)
      execute :append, context
    end

    def transform(page, error, &block)
      default = yield
      result = execute(:transform, page, error, default)
      if result.empty?
        default
      else
        result.join
      end
    end

    def analyze(typhoeus)
      execute :analyze, typhoeus
    end

    def collect(page)
      execute :collect, page
    end

    private

    class ErrorArray < Array
      def initialize(config)
        @config = config
      end

      def <<(error)
        if @config.ignored?(error)
          self
        else
          super
        end
      end
    end

    def extension(ext)
      @extensions << ext
    end

    def execute(method, *args)
      result = []
      @extensions.each do |e|
        result << e.send(method, *args) if e.respond_to? method
      end
      result
    end

    def default_pipeline
      extension(Blinkr::Extensions::Links.new(@config))
      extension(Blinkr::Extensions::JavaScript.new(@config))
    end

    def load_pipeline
      if @config.pipeline.nil?
        @logger.info('Loaded default pipeline'.yellow)
        default_pipeline
      else
        pipeline_file = File.join(File.dirname(@config.config_file), @config.pipeline)
        if File.exist?(pipeline_file)
          p = eval(File.read(pipeline_file), nil, pipeline_file, 1).load @config
          p.extensions.each do |e|
            extension(e)
          end
            @logger.info("Loaded custom pipeline from #{@config.pipeline}".yellow)
            pipeline = @extensions.inject {|memo, v| "#{memo}, #{v}"}
            @logger.info("Pipeline: #{pipeline}".yellow)
        else
          raise "Cannot find pipeline file #{pipeline_file}"
        end
      end
    end
  end
end
