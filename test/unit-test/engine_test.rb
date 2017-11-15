require_relative '../../test/unit-test/test_helper'
require 'minitest/autorun'
require 'open3'

class TestBlinkr < Minitest::Test

  describe Blinkr::TyphoeusWrapper do

    before do
      output = StringIO.new
      $stdout = output
    end

    it 'should check a single url' do
      options = {}
      options[:single_url] = 'http://www.example.com/foo/bar'
      @config = Blinkr::Config.new(options)
      stub_request(:get, options[:single_url]).to_return(status: 200)
      Blinkr::TyphoeusWrapper.new(@config, OpenStruct.new).debug(options[:single_url])
      assert_includes $stdout.string, 'Status Code: 200'
    end

    it 'should raise an error when a browser is not supported' do
      options = {}
      options[:browser] = 'firefox'
      options[:base_url] = 'http://www.example.com/f'

      exception = assert_raises(RuntimeError) {
        Blinkr.execute(options)
      }
      assert_includes(exception.message, "'firefox' is not a supported browser")
    end

    it 'should raise an error when a user specifies the remote flag for phantomjs' do
      options = {}
      options[:remote] = true
      options[:browser] = 'phantomjs'
      options[:base_url] = 'http://www.example.com/f'

      exception = assert_raises(RuntimeError) {
        Blinkr.execute(options)
      }
      assert_includes(exception.message, 'phantomjs cannot be executed using a remote browser, remove the --remote commandline arg')
    end
  end
end
