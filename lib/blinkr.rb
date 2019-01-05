require 'blinkr/version'
require 'blinkr/report'
require 'blinkr/config'
require 'blinkr/error'
require 'blinkr/formatter/default_logger'
require 'capybara/dsl'
require 'blinkr/engine'
require 'blinkr/drivers/capybara_driver'
require 'blinkr/drivers/page'

module Blinkr
  module_function

  def self.execute(options = {})
    config = if options[:config_file]
               Blinkr::Config.read(options[:config_file], options.tap { |hs| hs.delete(:config_file) })
             else
               Blinkr::Config.new(options)
             end

    context = Blinkr::Engine.new(config).run
    generate_report(context, config)
  end

  def generate_report(context, config)
    FileUtils.mkdir_p(Pathname.new(config.report).parent) unless config.export.nil?
    errors, warnings = Blinkr::Report.new(context, config).render
    if errors > 0 || warnings > 0
      Blinkr.logger.warn("Blinkr failed with #{errors} errors".red)
      status = 1
    else
      Blinkr.logger.info('Blinkr completed with no errors or warnings'.green)
      status = 0
    end
    status
  end
end
