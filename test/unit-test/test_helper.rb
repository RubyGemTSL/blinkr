require 'blinkr'
require 'minitest/reporters'
require 'webmock/minitest'
require 'mocha/minitest'
require 'rest-client'
reporter_options = {color: true}
include WebMock::API
Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(reporter_options)]

$is_unit_test = true

def sitemap_stub
  "<?xml version='1.0' encoding='UTF-8'?>
   <urlset xmlns='http://www.sitemaps.org/schemas/sitemap/0.9'>
   <url>
   <loc>#{__dir__}/test-site/home.htm/</loc>
   <lastmod>2017-06-14T11:21:47+01:00</lastmod>
   </url>
   </urlset>"
end

URLS = %w(http://www.example.com/ http://www.example.com/internal-link-1/ http://www.example.com/internal-link-2/ http://www.example.com/internal-link-3/ http://www.example.com/internal-link-4/ http://www.example.com/internal-link-5/ http://www.externalhost.com/external-link-1 http://www.externalhost.com/external-link-2 http://www.externalhost.com/external-link-3 http://www.externalhost.com/external-link-4 http://www.externalhost.com/external-link-5)

def stub_url(url, body, status)
  stub_request(:get, url).
      with(headers: {
          'Accept' => '*/*'
      }).
      to_return(status: status, body: body, headers: {})
end

def stub_urls(type)
  URLS.each do |url|
    if type == 'broken'
      stub_url(url, "404: You've found something, but not the page you're looking for.", 404)
    elsif type == 'socket'
      stub_request(:get, url).
          with(headers: {
              'Accept' => '*/*'
          }).
          to_raise(SocketError)
    elsif type == 'timeout'
      stub_request(:get, url).
          with(headers: {
              'Accept' => '*/*'
          }).
          to_raise(RestClient::Exceptions::Timeout)
    else
      stub_url(url, "200: All good", 200)
    end
  end
end

def get(url)
  begin
    RestClient::Request.execute(method: :get, url: url, max_redirects: 6, timeout: 30, verify_ssl: false)
  rescue RestClient::ExceptionWithResponse => err
    err.response
  end
end

def mock_robots_txt
  URLS.each do |url|
    uri = URI.parse(url)
    stub_url("#{uri.scheme}://#{uri.host}/robots.txt", robots, 200)
  end
end

def robots
  'User-agent: *'
end