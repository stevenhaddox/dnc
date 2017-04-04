require "simplecov"
SimpleCov.start

require_relative '../lib/dnc'
require 'awesome_print'
#require 'rspec/logging_helper'

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.filter_run_excluding :skip
  config.order = 'random'

  # Configure RSpec to capture log messages for each test. The output from the
  # logs will be stored in the @log_output variable. It is a StringIO instance.
#  include RSpec::LoggingHelper
#  config.capture_log_messages
end
