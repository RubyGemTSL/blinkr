require_relative '../../test/unit-test/test_helper'
require 'minitest/autorun'
require 'blinkr/sitemap'

class TestBlinkr < Minitest::Test

  describe Blinkr::Sitemap do

    before do
      # make private method testable by switching it to public
      # for the purposes of testing only.
      Blinkr::Sitemap.send(:public, :open_sitemap)
    end

    it 'should load a sitemap from a locally stored sitemap.xml file' do
      options = {}
      options[:custom_sitemap] = "#{__dir__}/config/sitemap.xml"
      @config = Blinkr::Config.new(options)
      sitemap = Blinkr::Sitemap.new(@config).open_sitemap
      assert_includes(sitemap.to_s, 'http://www.example.com/home')
    end

    it 'should load the sitemap from the base url' do
      options = {}
      options[:base_url] = 'http://www.example.com'
      stub_request(:get, "#{options[:base_url]}/sitemap.xml").to_return(status: 200, body: sitemap_stub, :headers => {})
      @config = Blinkr::Config.new(options)
      sitemap = Blinkr::Sitemap.new(@config).open_sitemap

      assert_includes(sitemap.to_s, 'test-site/blinkr.htm')
    end

    it 'should returns sitemap locations' do
      options = {}
      options[:base_url] = 'http://www.example.com'
      stub_request(:get, "#{options[:base_url]}/sitemap.xml").to_return(status: 200, body: sitemap_stub, :headers => {})
      @config = Blinkr::Config.new(options)
      sitemap = Blinkr::Sitemap.new(@config)
      assert_equal(1, sitemap.sitemap_locations.size)
    end
  end
end
