# frozen_string_literal: true

# Configure Shoulda Matchers if available
begin
  require "shoulda/matchers"

  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :rspec
      with.library :active_record if defined?(ActiveRecord)
      with.library :active_model if defined?(ActiveModel)
      with.library :action_controller if defined?(ActionController)
    end
  end
rescue LoadError
  # Shoulda matchers not available, skip configuration
end
