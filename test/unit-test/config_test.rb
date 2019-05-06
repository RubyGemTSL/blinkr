require_relative '../../test/unit-test/test_helper'
require 'minitest/autorun'

class TestBlinkr < Minitest::Test

  DEFAULTS = {
      skips: [], ignores: [], environments: [], max_retrys: 3,
      browser: 'chrome', report: 'blinkr.html', ignore_internal: false,
      ignore_external: false, js_errors: false, remote: false,
      verbose: false, empty_href: false, empty_img_alt: false,
      empty_title: false
  }.freeze

  describe Blinkr::Config do

    it 'should raise an error if it cannot read config file' do
      options = {}
      args = {}
      options[:config_file] = '/no/way/this/exists.yaml'
      exception = assert_raises(RuntimeError) {
        Blinkr::Config.read(options[:config_file], args)
      }
      assert_equal("Cannot read #{options[:config_file]}, config file does not exist.", exception.message)
    end

    it 'should create a default hash when no config file is specified' do
      options = {}
      actual_hash = Blinkr::Config.new(options)
      assert_equal(DEFAULTS, actual_hash.to_h)
    end

    it 'should merge user specified options and default config options' do
      options = {}
      args = {}
      options[:config_file] = "#{__dir__}/config/valid_blinkr.yaml"
      actual_hash = Blinkr::Config.read(options[:config_file], args)
      expected_hash = { skips: [/^http:\/\/(www\.)?example\.com\/foo/], ignores: [], environments: [], max_retrys: 3, browser: 'chrome', report: 'foo/blinkr.html', ignore_internal: false, ignore_external: false, js_errors: false, remote: false, verbose: false, empty_href: false, empty_img_alt: false, empty_title: false, base_url: 'http://www.example.com/', threads: 20, config_file: "#{__dir__}/config/valid_blinkr.yaml" }
      assert_equal expected_hash.to_s, actual_hash.to_h.to_s
    end

    it 'should expect ignores to contain a Hash' do
      options = {}
      args = {}
      options[:config_file] = "#{__dir__}/config/invalid_ignores.yaml"
      exception = assert_raises(RuntimeError) {
        Blinkr::Config.read(options[:config_file], args).validate
      }
      assert_equal('An ignore must be a hash', exception.message)
    end

    it 'should raise an error when a base url is not specified' do
      options = {}
      exception = assert_raises(RuntimeError) {
        Blinkr::Config.new(options).validate
      }
      assert_equal('Must specify base_url', exception.message)
    end

    it 'should append the base url with /sitemap.xml if not specified' do
      options = {}
      options[:base_url] = 'http://www.example.com'
      assert_equal("#{options[:base_url]}/sitemap.xml", Blinkr::Config.new(options).sitemap)
    end

    it 'should accept a custom sitemap in url format' do
      options = {}
      args = {}
      options[:config_file] = "#{__dir__}/config/blinkr_custom_sitemap_url.yaml"
      assert_equal('http://foobar.com/sitemap.xml', Blinkr::Config.read(options[:config_file], args).sitemap)
    end

    it 'should accept sitemap as local xml filetype' do
      options = {}
      args = {}
      options[:config_file] = "#{__dir__}/config/blinkr_custom_sitemap_filetype.yml"
      assert_equal("#{__dir__}/config/sitemap.xml", Blinkr::Config.read(options[:config_file], args).sitemap)
    end

    it 'should raise an error when locally stored sitemap.xml cannot be found' do
      options = {}
      args = {}
      options[:config_file] = "#{__dir__}/config/blinkr_custom_sitemap_filetype_none_existing.yaml"
      exception = assert_raises(RuntimeError) {
        Blinkr::Config.read(options[:config_file], args).sitemap
      }
      assert_equal('Unable to find file named idontexist.xml', exception.message)
    end

    it 'should raise an error when max_page_retrys is not specified' do
      options = {}
      options[:base_url] = 'http://www.example.com'
      options[:max_retrys] = nil
      exception = assert_raises(RuntimeError) {
        config = Blinkr::Config.new(options)
        config.max_page_retrys
      }
      assert_equal('Retrys is nil', exception.message)
    end

    it 'should ignore user specified ignored urls specified in Regex' do
      error = Blinkr::Error.new(severity: 'danger',
                                category: 'Broken link',
                                type: '<a href=""> target cannot be loaded',
                                url: 'http://www.example.com/foo', title: 'Foobar',
                                code: 500, message: 'Foobar',
                                detail: 'detail', snippet: '',
                                icon: 'fa-bookmark-o')
      options = {}
      args = {}
      options[:config_file] = "#{__dir__}/config/valid_regex_ignores.yaml"
      ignores = Blinkr::Config.read(options[:config_file], args).ignored?(error)
      assert_equal(ignores, true)
    end

    it 'should ignore user specified ignored urls specified as a string' do
      error = Blinkr::Error.new(severity: 'danger',
                                type: '<a href=""> target cannot be loaded',
                                url: 'http://www.example.com/foo', title: 'Foobar',
                                code: 500, message: 'Foobar',
                                detail: 'detail', snippet: '',
                                icon: 'fa-bookmark-o')
      options = {}
      args = {}
      options[:config_file] = "#{__dir__}/config/valid_string_ignores.yaml"
      ignores = Blinkr::Config.read(options[:config_file], args).ignored?(error)
      assert_equal(ignores, true)
    end

    it 'should return a boolean when no matched urls are found' do
      error = Blinkr::Error.new(severity: 'danger',
                                type: '<a href=""> target cannot be loaded',
                                url: 'http://www.foo.com/bar', title: 'Foobar',
                                code: 500, message: 'Foobar',
                                detail: 'detail', snippet: "<a href='/foo/'>Oh Hi</a>",
                                icon: 'fa-bookmark-o')
      options = {}
      args = {}
      options[:config_file] = "#{__dir__}/config/valid_string_ignores.yaml"
      ignores = Blinkr::Config.read(options[:config_file], args).ignored?(error)
      assert_equal(ignores, false)
    end

    it 'should ignore user specified error codes' do
      error = Blinkr::Error.new(severity: 'danger',
                                type: '<a href=""> target cannot be loaded',
                                url: 'http://www.foo.com/bar', title: 'Foobar',
                                code: 404, message: 'Foobar',
                                detail: 'detail', snippet: '',
                                icon: 'fa-bookmark-o')
      options = {}
      args = {}
      options[:config_file] = "#{__dir__}/config/valid_string_ignores.yaml"
      ignores = Blinkr::Config.read(options[:config_file], args).ignored?(error)
      assert_equal(ignores, true)
    end

    it 'should return false when no matched error codes are found' do
      error = Blinkr::Error.new(severity: 'danger',
                                type: '<a href=""> target cannot be loaded',
                                url: 'http://www.foo.com/bar', title: 'Foobar',
                                code: 503, message: 'Foobar',
                                detail: 'detail', snippet: '',
                                icon: 'fa-bookmark-o')
      options = {}
      args = {}
      options[:config_file] = "#{__dir__}/config/valid_string_ignores.yaml"
      ignores = Blinkr::Config.read(options[:config_file], args).ignored?(error)
      assert_equal(ignores, false)
    end


    it 'should ignore user specified messages' do
      error = Blinkr::Error.new(severity: 'danger',
                                type: '<a href=""> target cannot be loaded',
                                url: 'http://www.foo.com/bar', title: 'Foobar',
                                code: 500, message: 'Not Found',
                                detail: 'detail', snippet: '',
                                icon: 'fa-bookmark-o')
      options = {}
      args = {}
      options[:config_file] = "#{__dir__}/config/valid_string_ignores.yaml"
      ignores = Blinkr::Config.read(options[:config_file], args).ignored?(error)
      assert_equal(ignores, true)
    end

    it 'should return false when no matched messages are found' do
      error = Blinkr::Error.new(severity: 'danger',
                                type: '<a href=""> target cannot be loaded',
                                url: 'http://www.foo.com/bar', title: 'Foobar',
                                code: 503, message: 'Foobar',
                                detail: 'detail', snippet: '',
                                icon: 'fa-bookmark-o')
      options = {}
      args = {}
      options[:config_file] = "#{__dir__}/config/valid_string_ignores.yaml"
      ignores = Blinkr::Config.read(options[:config_file], args).ignored?(error)
      assert_equal(ignores, false)
    end


    it 'should ignore user specified snippet' do
      error = Blinkr::Error.new(severity: 'danger',
                                type: '<a href=""> target cannot be loaded',
                                url: 'http://www.foo.com/bar', title: 'Foobar',
                                code: 500, message: 'Foobar',
                                detail: 'detail', snippet: "<a href='/foo/'>I'm a link</a>",
                                icon: 'fa-bookmark-o')
      options = {}
      args = {}
      options[:config_file] = "#{__dir__}/config/valid_string_ignores.yaml"
      ignores = Blinkr::Config.read(options[:config_file], args).ignored?(error)
      assert_equal(ignores, true)
    end

    it 'should return false when no matched ignored snippets are found' do
      error = Blinkr::Error.new(severity: 'danger',
                                type: '<a href=""> target cannot be loaded',
                                url: 'http://www.foo.com/bar', title: 'Foobar',
                                code: 503, message: 'Foobar',
                                detail: 'detail', snippet: "<a href='/foo/'>Oh Hi</a>",
                                icon: 'fa-bookmark-o')
      options = {}
      args = {}
      options[:config_file] = "#{__dir__}/config/valid_string_ignores.yaml"
      ignores = Blinkr::Config.read(options[:config_file], args).ignored?(error)
      assert_equal(ignores, false)
    end

    it 'should skip user configured links/pages specified in String' do
      options = {}
      args = {}
      options[:config_file] = "#{__dir__}/config/valid_skips.yaml"
      skips = Blinkr::Config.read(options[:config_file], args).skipped?('http://www.example.com/bar')
      assert_equal(true, skips)
    end

    it 'should skip user configured links/pages specified in Regex' do
      options = {}
      args = {}
      options[:config_file] = "#{__dir__}/config/valid_skips.yaml"
      skips = Blinkr::Config.read(options[:config_file], args).skipped?('http://www.example.com/regex')
      assert_equal(true, skips)
    end

  end
end
