require 'blinkr/error'

module Blinkr
  module Extensions
    class ImgAlt
      def initialize(config)
        @config = config
      end

      def collect(page)
        page.body.css('img:not([alt])').each do |img|
          page.errors << ::Blinkr::Error.new(severity: :warning,
                                             category: 'SEO',
                                             type: '<img alt=""> missing',
                                             title: "#{img['src']} (line #{img.line})",
                                             message: '<img alt=""> missing', snippet: img.to_s,
                                             icon: 'fa-info')
        end if @config.empty_img_alt
      end
    end
  end
end
