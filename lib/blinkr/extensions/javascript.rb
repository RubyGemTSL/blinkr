require 'blinkr/error'

module Blinkr
  module Extensions
    class JavaScript
      def initialize(config)
        @config = config
      end

      def collect(page)
        page.javascript_errors.each do |error|
          page.errors << Blinkr::Error.new(severity: error['level'],
                                           category: 'JavaScript',
                                           type: 'JavaScript error',
                                           title: nil,
                                           snippet: error['message'],
                                           icon: 'fa-bookmark-o')
        end if @config.js_errors
      end
    end
  end
end
