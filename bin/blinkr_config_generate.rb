#!/usr/bin/env ruby
require 'fileutils'
require 'colorize'

class BlinkrConfigGenerator

  def initialize(test_dir)
    @default_config = File.join(File.dirname(test_dir), '.', 'default-config/blinkr.yml')
  end

  def create_default_config
    FileUtils.cp_r(@default_config, '.')
    puts("Generated blinkr config file and saved to #{Dir.pwd}".green)
  end

end

def execute(blinkr_setup)
  config_generated = blinkr_setup.create_default_config
  Kernel.exit(config_generated ? 0 : 1)
end

if $PROGRAM_NAME == __FILE__
  generate_config = BlinkrConfigGenerator.new(__dir__)
  execute(generate_config)
end
