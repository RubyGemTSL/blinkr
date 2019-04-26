require 'ostruct'
require 'uri'
require 'erb'
require 'yaml'

module Blinkr
  #
  # This class generates a default config, or merges user specified custom
  # config settings.
  #
  class Config < OpenStruct

    def self.read(file, args)
      raise("Cannot read #{file}, config file does not exist.") unless File.exist?(file)
      config = YAML.load(ERB.new(File.read(file)).result)
      Config.new(config.merge(args).merge(config_file: file))
    end

    DEFAULTS = {
        skips: [], ignores: [], environments: [], max_retrys: 3, browser: 'chrome', report: 'blinkr.html',
        ignore_internal: false, ignore_external: false, js_errors: false, remote: false, verbose: false
    }.freeze

    def initialize(hash = {})
      super(DEFAULTS.merge(hash))
    end

    def validate
      ignores.each { |ignore| raise 'An ignore must be a hash' unless ignore.is_a? Hash }
      raise 'Must specify base_url' if base_url.nil?
      self
    end

    def sitemap
      if custom_sitemap.nil?
        base_url << '/' if base_url[-1] != '/'
        URI.join(base_url, 'sitemap.xml').to_s
      else
        uri = URI(custom_sitemap)
        unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
          unless File.exist?(custom_sitemap)
            raise "Unable to find file named #{custom_sitemap}"
          end
        end
        custom_sitemap
      end
    end

    def max_page_retrys
      r = super || max_retrys
      raise 'Retrys is nil' if r.nil?
      r
    end

    def ignored?(error)
      url = error.url
      code = error.code
      message = error.message
      snippet = error.snippet

      ignores.any? do |ignore|
        if ignore.key? 'url'
          return true if ignore['url'].is_a?(Regexp) && url && ignore['url'] =~ url
          return true if ignore['url'] == url
        end

        if ignore.key? 'code'
          return true if ignore['code'].is_a?(Regexp) && code && ignore['code'] == code
          return true if ignore['code'] == code
        end

        if ignore.key? 'message'
          return true if ignore['message'].is_a?(Regexp) && message && ignore['message'] =~ message
          return true if ignore['message'] == message
        end

        if ignore.key? 'snippet'
          return true if ignore['snippet'].is_a?(Regexp) && snippet && ignore['snippet'] =~ snippet
          return true if ignore['snippet'] == snippet
        end

        false
      end
    end

    def skipped?(url)
      if skips.any? do |skip|
        if skip.is_a?(Regexp)
          return true if skip =~ url
        else
          return true if skip == url
        end
      end
      end
    end
  end
end
