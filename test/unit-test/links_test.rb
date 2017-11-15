require_relative 'test_helper'
require 'minitest/autorun'
require 'blinkr/sitemap'
require 'blinkr/error'
require 'blinkr/drivers/typhoeus_wrapper'

class TestBlinkr < Minitest::Test

  describe Blinkr::Extensions::Links do

    before do
      @test_site = Nokogiri::HTML(File.read("#{File.expand_path(".")}/test/test-site/blinkr.htm"))
      @options = {}
      @options[:base_url] = 'http://www.example.com'
      @response = Typhoeus::Response.new(code: 200, body: @test_site, effective_url: @options[:base_url])
      @page = Typhoeus.stub(@options[:base_url]).and_return(@response)
    end

    it 'should collect all inks from pages unless otherwise stated' do
      @config = Blinkr::Config.new(@options)

      links = Blinkr::Extensions::Links.new(@config)
      result = OpenStruct.new(response: @page[0],
                              body: @page[0].body.freeze,
                              errors: nil,
                              resource_errors: [],
                              javascript_errors: [])
      assert_equal(10, links.collect(result).size)
    end

    it 'should only check internal urls when user specifies --ignore-external' do
      @options[:ignore_external] = true
      @config = Blinkr::Config.new(@options)

      links = Blinkr::Extensions::Links.new(@config)
      result = OpenStruct.new(response: @page[0],
                              body: @page[0].body.freeze,
                              errors: nil,
                              resource_errors: [],
                              javascript_errors: [])
      assert_equal(5, links.collect(result).size)
    end

    it 'should only test external urls user specifies --ignore-internal' do
      @options[:ignore_internal] = true
      @config = Blinkr::Config.new(@options)

      links = Blinkr::Extensions::Links.new(@config)
      result = OpenStruct.new(response: @page[0],
                              body: @page[0].body.freeze,
                              errors: nil,
                              resource_errors: [],
                              javascript_errors: [])
      assert_equal(5, links.collect(result).size)
    end

    it 'should analyze pages and report no errors when all links are passing' do
      urls('ok')
      @config = Blinkr::Config.new(@options)

      links = Blinkr::Extensions::Links.new(@config)
      result = OpenStruct.new(response: @page[0],
                              body: @page[0].body.freeze,
                              errors: ErrorArray.new(@config),
                              resource_errors: [],
                              javascript_errors: [])

      context = OpenStruct.new(pages: {})
      links.collect(result)
      context.pages[@options[:base_url]] = @page

      browser = Blinkr::TyphoeusWrapper.new(@config, context)
      links.analyze(context, browser)
      assert_equal(0, result.errors.size)

    end

    it 'should analyze pages and report errors when urls are broken' do
      urls('broken')
      @config = Blinkr::Config.new(@options)

      links = Blinkr::Extensions::Links.new(@config)
      result = OpenStruct.new(response: @page[0],
                              body: @page[0].body.freeze,
                              errors: ErrorArray.new(@config),
                              resource_errors: [],
                              javascript_errors: [])
      context = OpenStruct.new(pages: {})
      links.collect(result)
      context.pages[@options[:base_url]] = @page

      browser = Blinkr::TyphoeusWrapper.new(@config, context)
      links.analyze(context, browser)
      assert_equal(10, result.errors.size)
    end

    it 'should analyze pages and report warnings when user specifies environments array' do
      urls('ok')
      @options[:environments] = ['http://www.externalhost.com']
      @config = Blinkr::Config.new(@options)

      links = Blinkr::Extensions::Links.new(@config)
      result = OpenStruct.new(response: @page[0],
                              body: @page[0].body.freeze,
                              errors: ErrorArray.new(@config),
                              resource_errors: [],
                              javascript_errors: [])
      context = OpenStruct.new(pages: {})
      links.collect(result)
      context.pages[@options[:base_url]] = @page

      browser = Blinkr::TyphoeusWrapper.new(@config, context)
      links.analyze(context, browser)
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
