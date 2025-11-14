# frozen_string_literal: true

require_relative "zenspec/version"
require_relative "zenspec/matchers"
require_relative "zenspec/helpers"
require_relative "zenspec/shoulda_config"

# Load Railtie if Rails is available
require_relative "zenspec/railtie" if defined?(Rails::Railtie)

module Zenspec
  class Error < StandardError; end
end
