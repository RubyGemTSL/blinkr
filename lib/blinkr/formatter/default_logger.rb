require 'colorize'
require 'logger'

# global logger for blinkr.
module Blinkr
  class << self
    attr_accessor :logger
  end
end

Blinkr.logger = Logger.new(STDOUT)
