require 'capybara'
require 'capybara/dsl'
require 'selenium-webdriver'
require 'blinkr/formatter/default_logger'

module Blinkr
  # This class sets up the driver for capybara. Used internally by Blinkr
  class Driver

    USER_AGENT_STRING = 'Blinkr broken-link checker'.freeze

    def browser(is_remote)
      if is_remote.nil?
        chrome
      else
        remote_chrome
      end
    end

    private

    def chrome
      Capybara.register_driver :selenium do |app|
        options = Selenium::WebDriver::Chrome::Options.new
        options.add_argument('--headless')
        options.add_argument('--disable-gpu')
        options.add_argument('--no-sandbox')
        options.add_argument("user-agent=#{USER_AGENT_STRING}")
        options.add_argument('--allow-running-insecure-content')
        options.add_argument('--ignore-certificate-errors')
        Capybara::Selenium::Driver.new app,
                                       browser: :chrome,
                                       options: options
      end

      Capybara.default_driver = :selenium
      @browser = Capybara.current_session
      raise 'Driver could not be properly initialized' unless @browser
      @browser
    end

    def remote_chrome
      sel_host = ENV['GRID_HOST'] || 'localhost'
      sel_port = ENV['GRID_PORT'] || '4444'
      Capybara.register_driver :selenium_remote_chrome do |app|
        capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
            chromeOptions: {
                args: ['no-sandbox',
                       'allow-running-insecure-content',
                       'ignore-certificate-errors',
                       "user-agent=#{USER_AGENT_STRING}"]
            })
        Capybara::Selenium::Driver.new(
            app,
            browser: :remote,
            url: "http://#{sel_host}:#{sel_port}/wd/hub",
            desired_capabilities: capabilities
        )
      end

      Capybara.run_server = false
      Capybara.server_host = '0.0.0.0'
      Capybara.default_max_wait_time = 60
      Capybara.default_driver = :selenium_remote_chrome
      @browser = Capybara.current_session
      raise 'Driver could not be properly initialized' unless @browser
      @browser
    end
  end
end
