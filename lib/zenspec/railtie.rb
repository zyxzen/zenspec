# frozen_string_literal: true

module Zenspec
  class Railtie < Rails::Railtie
    railtie_name :zenspec

    rake_tasks do
      # Add rake tasks if needed in the future
    end

    initializer "zenspec.configure_rspec" do
      # Automatically configure zenspec matchers and helpers when Rails loads
      if defined?(RSpec)
        RSpec.configure do |config|
          # Include matchers
          config.include Zenspec::Matchers::InteractorMatchers
          config.include Zenspec::Matchers::GraphQLMatchers
          config.include Zenspec::Matchers::GraphQLTypeMatchers

          # Include helpers
          config.include Zenspec::Helpers::GraphQLHelpers
        end
      end
    end
  end
end
