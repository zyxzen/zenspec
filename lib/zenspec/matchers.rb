# frozen_string_literal: true

require_relative "matchers/interactor_matchers"
require_relative "matchers/graphql_matchers"
require_relative "matchers/graphql_type_matchers"

module Zenspec
  module Matchers
    # This module serves as a namespace for all Zenspec matchers
    # Individual matcher modules are loaded from their respective files
  end
end
