require_relative '../../../lib/blinkr/formatter/default_logger'
require_relative '../../../lib/blinkr/drivers/capybara_driver'
require 'json'

module Blinkr
  # This class navigates to a url, waits for page to render/load, returns body.
  class Page
    include Capybara::DSL
    attr_reader :browser, :info

    def initialize(remote)
      @browser = Driver.new.browser(remote)
      @info = {}
    end

    def get_page(url)
      visit(url)
      wait_for_ajax_completion
      @info[:javascriptErrors] = js_errors
      @info[:url] = url
      @info[:content] = page.html
      return $stdout.write(@info.to_json), exit(0)
    rescue => exception
      return $stdout.write(exception), exit(1)
    end

    private

    def wait_for_ajax_completion
      2.times {
        wait_for_requests
      }
    end

    def wait_for_requests
      Timeout.timeout(50) do
        active = requests?
        page_load = js_loaded?
        js_loaded = finished_all_ajax_requests?
        until active == 0 && page_load == 'complete' && js_loaded
          active = requests?
          js_loaded = js_loaded?
        end
      end
      # double check in case we've been redirected
      sleep(2)
    end

    def requests?
      @browser.evaluate_script('window.$.active').to_i
    end

    def js_loaded?
      @browser.evaluate_script('document.readyState')
    end

    def finished_all_ajax_requests?
      @browser.evaluate_script('jQuery.active').zero?
    end

    def js_errors
      errors = []
      @browser.driver.browser.manage.logs.get(:browser).map do |error|
        errors << { level: error.level.downcase, message: error.message }
      end
      errors
    end
  end
end

def go(driver, url)
  driver.get_page(url)
end

if $PROGRAM_NAME == __FILE__
  url = ARGV[0]
  remote = ARGV[1]
  driver = Blinkr::Page.new(remote)
  go(driver, url)
end
