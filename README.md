# Blinkr

A broken link checker for websites. Uses headless Chrome to render pages in order to check for broken links created by JS, and can (optionally) check for JavaScript errors. 

Blinkr determines which pages to load from your `sitemap.xml`, once pages are loaded it will then use [RestClient](https://github.com/rest-client/rest-client) to check link status. Links are cached, therefore blinkr will not duplicate already checked links.

Blinkr respects an external website's robots.txt file, in order to obey the site rules for Crawl-delay, and prevent overloading servers with too many requests. 

At the end of the checks, if your site contains broken links an html report will be generated that will include any broken links (more below).

## Installation

Add this line to your application's Gemfile:

    gem 'blinkr'

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install blinkr

You will need [chrome](http://chromedriver.chromium.org/downloads) to render pages, therefore you must add chromedriver to your path. Optionally for speed and ease of use you can use [docker-selenium](https://github.com/SeleniumHQ/docker-selenium) as a remote browser. For example;

Set config to use a remote browser:
      
      $ docker run -d -p 4444:4444 -v /dev/shm:/dev/shm selenium/standalone-chrome:3.141.59-dubnium

Use your own grid, or standalone server by setting the following environment variables.      
      
      ENV['GRID_HOST'] = your selenium grid or standalone host (defaults to 'localhost')
      ENV['GRID_PORT'] = your selenium grid or standalone port (defaults to '4444')
      
      $ bundle exec blinkr --remote=true

## Quickstart

To run blinkr against your site checking every `a[href]` link on all your pages:

````
bundle exec blinkr -u https://developers.redhat.com
````

## Configuration
By default blinkr will check all links that are found on pages within your sitemap. To see the command line interface help just type the following command in your terminal:
````
$ bundle exec blinkr -h
Usage: blinkr [options]
   -c, --config FILE            Specify the config.yaml file
   -u, --base-url URL           Specify the URL of the site root
   -v, --verbose                Output debugging info to the console
   --gen                        Create a blinkr configuration file
   --ignore-external            Ignore external links
   --ignore-internal            Ignore internal links
   --remote                     Run checks using remote browser

````

As well as the above commandline options, Blinkr can be customised by creating a config file `blinkr.yml`. Using the blinkr configuration helper it is easy to generate a config file. 

Just run: `bundle exec blinkr --gen`

The following `blinkr.yml` file will be generated. NOTE, this includes all available config options. Custom configurations are merged with the default config therefore you may customise one or more configuration options - just remove options not applicable to you.

```` 
#
# The URL to check (often specified on the command line)
#
base_url: https://www.example.com

#
# Use remote browser (default: false)
#
remote: false

#
# Specify a sitemap to use, rather than the default <base_url>/sitemap.xml
# Can be a url or a .xml file
# example of alternative url sitemap:
# custom_sitemap: https://www.foo.com/my_sitemap.xml
# example of local sitemap file, use ruby to specify the location of the sitemap.xml file
# <% sitemap_loc = "#{File.dirname(File.expand_path('.', __FILE__))}/local-sitemap.xml" %>
#custom_sitemap: <%= sitemap_loc %>
#
custom_sitemap: https://www.foo.com/my_sitemap.xml

#
# Links and pages not to check (may be a regexp or a string).
# skips:
#  - !ruby/regexp /^https:\/\/developers\.redhat\.com\/quickstarts\.*\/.*/
#  - https://developers.redhat.com/dont/test/me
#
skips:

#
# Errors to ignore when generating the output. Each ignore should be a hash
# containing a url (may be regexp or a string), an error code (integer) and a
# error message (may be a regexp or a string)
#ignores:
   # - url: http://www.acme.com/foo
   # - url: !ruby/regexp /^https?:\/\/(www\.)?acme\.com\/bar\/
   #  message: Not Found
   #  code: 500
#
ignores:

#
# Warn if links are using an incorrect environment, for example staging environment using production links that may interfere with site stats:
# For example, your base_url: https://staging.environment.com
# list elements as string:
#  - https://prodcution.foo.com
#  - https://production-foo.drupal.com
#
environments:

#
#
threads: 10

#
# The number of times to try reloading a link, if the server doesn't respond or
# refuses the connection. If the retry limit is exceeded, it will be reported as
# 'Server timed out' in the report. By default 3.
#
max_retrys: 3

#
# set to true if you only want to test external urls. Internal urls are anything that contains the base_url
#
ignore_internal: false

#
# set to true if you only want to test internal urls. Internal urls are anything that contains the base_url
#
ignore_external: false

#
# Set to true if you wish to report any js-errors found in the console.
#
warn_js_errors: false

#
# The output file to write the report to
#
report: 'blinkr.html'

````

You can specify a custom config file on the command link:

````
blinkr -c path/to/my/config/staging_blinkr.yml
````

If you want to see more details about the URLs blinkr is checking, you can use
the `-v` option:

`bundle exec blinkr -c path/to/my/config/my_blinkr.yml -u https://foo..com -v`

If you need to debug why a particular URL is being reported as bad using
blinkr, but works in your web browser, you can load a single URL using typhoeus:

````
bundle exec blinkr -s http://www.foo.com/bar
````

## History
Blinkr was originally created by [Pete Muir](https://github.com/pmuir), however as he is no longer maintaining Blinkr, we at the Red Hat Developer Program have decided to resurrect it. Thank you to Pete for your hard work in kicking off the work on this.

## Contributing

Please feel free to help us improve Blinkr!

1. Fork it ( https://github.com/redhat-developer/blinkr/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Test it, this is important! to run the existing tests (`bundle exec rake test`), however please create unit-test's for new features.
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
