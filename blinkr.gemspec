# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'blinkr/version'

Gem::Specification.new do |spec|
  spec.name = 'blinkr'
  spec.version = Blinkr::VERSION
  spec.authors = %w[Ian Hamilton Jason Porter Pete Muir]
  spec.email = %w[ian.ross.hamilton@gmail.com lightguard.jp@gmail.com pmuir@bleepbleep.org.uk]
  spec.summary = 'A simple broken link checker'
  spec.description = <<-EOF
       A broken page and link checker for websites. Optionally uses chrome or phantomjs to render pages to check resource loading,
       links created by JS, and report any JS page load errors.
  EOF
  spec.homepage = 'https://github.com/redhat-developer/blinkr'
  spec.license = 'Apache-2.0'

  spec.files = `git ls-files`.split($RS)
  spec.files -= %w[.gitignore .ruby-version .ruby-gemset]
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.2.2'

  spec.add_dependency 'capybara', '~> 3.1'
  spec.add_dependency 'nokogiri', '~> 1.8'
  spec.add_dependency 'typhoeus', '~> 1.3'
  spec.add_dependency 'slim', '~> 3.0', '>= 3.0.9'
  spec.add_dependency 'parallel', '~> 1.12', '>= 1.12.1'
  spec.add_dependency 'selenium-webdriver', '~> 3.8'
  spec.add_dependency 'ffi', '1.9.18'
  spec.add_development_dependency 'rake', '~> 10.3'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'webmock', '~> 3.3'
  spec.add_development_dependency 'timecop', '~> 0.9.1'
  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'byebug', '~> 4.0'
  spec.add_development_dependency 'minitest', '~> 5.10', '>= 5.10.2'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_runtime_dependency 'colorize'
end
