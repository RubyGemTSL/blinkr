require 'slim'
require 'ostruct'
require 'blinkr/error'
require 'fileutils'

module Blinkr
  class Report
    require 'colorize'
    HTML_REPORT_TMPL = File.expand_path('report.html.slim', File.dirname(__FILE__))

    def self.render(context, config)
    end

    def initialize(context, config)
      @context = context
      @config = config
      @logger = Blinkr.logger
    end

    def render
      @context.total = 0
      @context.severity = {}
      @context.category = {}
      @context.type = {}
      @context.pages.each do |url, page|
        page.url = url
        page.severities = []
        page.categories = []
        page.types = []
        page.errors.each do |error|
          @context.total += 1
          @context.severity[error.severity] ||= OpenStruct.new(count: 0)
          @context.severity[error.severity].count += 1
          page.severities << error.severity
          @context.category[error.category] ||= OpenStruct.new(count: 0)
          @context.category[error.category].count += 1
          page.categories << error.category
          @context.type[error.type] ||= OpenStruct.new(count: 0)
          @context.type[error.type].count += 1
          page.types << error.type
        end
        page.severities.uniq!
        page.categories.uniq!
        page.types.uniq!
      end
      @context.pages = @context.pages.values
      File.open(@config.report, 'w') do |file|
        file.write(Slim::Template.new(HTML_REPORT_TMPL).render(OpenStruct.new(blinkr: @context, errors: @context.to_json)))
      end
      errors = 0
      Blinkr::SEVERITY.each do |severity|
        unless @context.severity[severity].nil?
          errors += @context.severity[severity].count
        end
      end
      errors
    end
  end
end
