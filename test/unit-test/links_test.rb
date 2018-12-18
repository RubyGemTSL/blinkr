require_relative 'test_helper'
require 'minitest/autorun'
require 'blinkr/sitemap'
require 'blinkr/error'

class TestBlinkr < Minitest::Test

  describe Blinkr::Extensions::Links do

    before do
      @test_site =File.read("#{File.expand_path(".")}/test/test-site/home.htm")
      @options = {}
      @options[:base_url] = 'http://www.example.com'
      stub_url(@options[:base_url], @test_site, 200)
      mock_robots_txt
    end

    it 'should collect all inks from pages unless otherwise stated' do
      @config = Blinkr::Config.new(@options)
      response = get(@options[:base_url])
      body = Nokogiri::HTML(response.body)
      result = OpenStruct.new(response: response,
                              body: body.freeze,
                              errors: ErrorArray.new(@config),
                              javascript_errors: [])
      links = Blinkr::Extensions::Links.new(@config)

      assert_equal(10, links.collect(result).size)
    end

    it 'should only check internal urls when user specifies --ignore-external' do
      @options[:ignore_external] = true
      @config = Blinkr::Config.new(@options)
      response = get(@options[:base_url])
      body = Nokogiri::HTML(response.body)
      result = OpenStruct.new(response: response,
                              body: body.freeze,
                              errors: ErrorArray.new(@config),
                              javascript_errors: [])
      links = Blinkr::Extensions::Links.new(@config)

      assert_equal(5, links.collect(result).size)
    end

    it 'should only test external urls user specifies --ignore-internal' do
      @options[:ignore_internal] = true
      @config = Blinkr::Config.new(@options)
      response = get(@options[:base_url])
      body = Nokogiri::HTML(response.body)
      result = OpenStruct.new(response: response,
                              body: body.freeze,
                              errors: ErrorArray.new(@config),
                              javascript_errors: [])
      links = Blinkr::Extensions::Links.new(@config)

      assert_equal(5, links.collect(result).size)
    end

    it 'should analyze pages and report no errors when all links are passing' do
      @config = Blinkr::Config.new(@options)
      response = get(@options[:base_url])
      body = Nokogiri::HTML(response.body)
      result = OpenStruct.new(response: response,
                              body: body.freeze,
                              errors: ErrorArray.new(@config),
                              javascript_errors: [])
      links = Blinkr::Extensions::Links.new(@config)
      links.collect(result)

      context = OpenStruct.new(pages: {})
      context.pages[@options[:base_url]] = response.request.url
      browser = Blinkr::RestClientWrapper.new(@config, context)
      stub_urls('ok')
      links.analyze(browser)
      assert_equal(0, result.errors.size)

    end

    it 'should analyze pages and report errors when urls are broken' do
      @config = Blinkr::Config.new(@options)
      response = get(@options[:base_url])
      body = Nokogiri::HTML(response.body)
      result = OpenStruct.new(response: response,
                              body: body.freeze,
                              errors: ErrorArray.new(@config),
                              javascript_errors: [])
      links = Blinkr::Extensions::Links.new(@config)
      links.collect(result)

      context = OpenStruct.new(pages: {})
      context.pages[@options[:base_url]] = response.request.url
      browser = Blinkr::RestClientWrapper.new(@config, context)
      stub_urls('broken')
      links.analyze(browser)
      assert_equal(10, result.errors.size)
    end

    it "should handle invalid urls" do
      @config = Blinkr::Config.new(@options)
      response = get(@options[:base_url])
      body = Nokogiri::HTML(response.body)
      result = OpenStruct.new(response: response,
                              body: body.freeze,
                              errors: ErrorArray.new(@config),
                              javascript_errors: [])
      links = Blinkr::Extensions::Links.new(@config)
      links.collect(result)

      context = OpenStruct.new(pages: {})
      context.pages[@options[:base_url]] = response.request.url
      browser = Blinkr::RestClientWrapper.new(@config, context)
      stub_urls('socket')
      links.analyze(browser)
      assert_equal(10, result.errors.size)
    end

    it 'should analyze pages and report warnings when user specifies environments array' do
      @options[:environments] = ['http://www.externalhost.com']
      @config = Blinkr::Config.new(@options)
      response = get(@options[:base_url])
      body = Nokogiri::HTML(response.body)
      result = OpenStruct.new(response: response,
                              body: body.freeze,
                              errors: ErrorArray.new(@config),
                              javascript_errors: [])
      links = Blinkr::Extensions::Links.new(@config)
      links.collect(result)

      context = OpenStruct.new(pages: {})
      context.pages[@options[:base_url]] = response.request.url
      browser = Blinkr::RestClientWrapper.new(@config, context)
      stub_urls('ok')
      links.analyze(browser)
      assert_equal(5, result.errors.size)
    end
  end
end

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
