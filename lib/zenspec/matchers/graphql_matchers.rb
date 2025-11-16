# frozen_string_literal: true

require "rspec/expectations"

module Zenspec
  module Matchers
    module GraphQLMatchers
      # Matcher for executing GraphQL queries and checking results
      #
      # @example
      #   expect(query).to execute_graphql
      #   expect(query).to execute_graphql.with_variables(id: "123")
      #   expect(query).to execute_graphql.with_context(current_user: user)
      #   expect(query).to execute_graphql.and_succeed
      #   expect(query).to execute_graphql.and_succeed.returning_data("user", "id")
      #
      RSpec::Matchers.define :execute_graphql do
        match do |query_string|
          @variables ||= {}
          @context ||= {}

          # Execute the query
          schema_class = defined?(AppSchema) ? AppSchema : GraphQL::Schema
          @result = schema_class.execute(
            query_string,
            variables: @variables,
            context: @context
          )

          # Check if we need to verify success
          if @check_success
            errors = @result["errors"]
            return false if !errors.nil? && (errors.is_a?(Array) ? !errors.empty? : true)
          end

          # Check if we need to return specific data
          if @data_path&.any?
            @returned_data = dig_data(@result["data"], @data_path)
            true
          else
            @result["errors"].nil? || @result["errors"].empty?
          end
        end

        chain :with_variables do |variables|
          @variables = variables
        end

        chain :with_context do |context|
          @context = context
        end

        chain :and_succeed do
          @check_success = true
        end

        chain :returning_data do |*path|
          @data_path = path
        end

        failure_message do
          errors = @result["errors"]
          has_errors = !errors.nil? && (errors.is_a?(Array) ? !errors.empty? : true)

          if has_errors
            "expected GraphQL query to succeed, but got errors: #{@result["errors"]}"
          elsif @data_path
            "expected to find data at path #{@data_path.inspect}, but result was: #{@result["data"].inspect}"
          else
            "expected GraphQL query to execute without errors, but got: #{@result["errors"]}"
          end
        end

        # Allow accessing the returned data
        def returned_data
          @returned_data
        end

        private

        def dig_data(data, path)
          path.reduce(data) do |current, key|
            return nil if current.nil?

            current.is_a?(Hash) ? current[key.to_s] : nil
          end
        end
      end

      # Matcher for checking if GraphQL result has data at a specific path
      #
      # @example
      #   expect(result).to have_graphql_data
      #   expect(result).to have_graphql_data("user")
      #   expect(result).to have_graphql_data("user", "id")
      #   expect(result).to have_graphql_data("user", "id").with_value("123")
      #   expect(result).to have_graphql_data("user").matching(id: "123", name: "John")
      #   expect(result).to have_graphql_data("user").that_includes(name: "John")
      #   expect(result).to have_graphql_data("users").that_is_present
      #   expect(result).to have_graphql_data("deletedAt").that_is_null
      #   expect(result).to have_graphql_data("users").with_count(5)
      #
      RSpec::Matchers.define :have_graphql_data do |*path|
        match do |result|
          data = path.empty? ? result["data"] : dig_data(result["data"], path)

          # Check for explicit null
          if @check_null
            return data.nil?
          end

          # Check for presence (not nil and not empty)
          if @check_present
            return !data.nil? && (data.respond_to?(:empty?) ? !data.empty? : true)
          end

          # Check count for arrays
          if @expected_count
            return false unless data.is_a?(Array)
            return data.length == @expected_count
          end

          # Check for partial matching (subset)
          if @expected_match
            return false unless data.is_a?(Hash)
            return @expected_match.all? { |key, value| data[key.to_s] == value }
          end

          # Check for inclusion (subset with any match)
          if @expected_include
            return false unless data.is_a?(Hash) || data.is_a?(Array)

            if data.is_a?(Hash)
              return @expected_include.all? { |key, value| data[key.to_s] == value }
            else
              # For arrays, check if any element matches
              return data.any? do |item|
                item.is_a?(Hash) && @expected_include.all? { |key, value| item[key.to_s] == value }
              end
            end
          end

          # Check exact value
          unless @expected_value.nil?
            data == @expected_value
          else
            !data.nil?
          end
        end

        chain :with_value do |expected_value|
          @expected_value = expected_value
        end

        chain :matching do |expected_hash|
          @expected_match = expected_hash
        end

        chain :that_includes do |expected_hash|
          @expected_include = expected_hash
        end

        chain :that_is_present do
          @check_present = true
        end

        chain :that_is_null do
          @check_null = true
        end

        chain :with_count do |expected_count|
          @expected_count = expected_count
        end

        failure_message do |result|
          data = path.empty? ? result["data"] : dig_data(result["data"], path)

          if @check_null
            "expected data at #{path.inspect} to be null, but got: #{data.inspect}"
          elsif @check_present
            "expected data at #{path.inspect} to be present, but it was #{data.inspect}"
          elsif @expected_count
            actual_count = data.is_a?(Array) ? data.length : "not an array"
            "expected data at #{path.inspect} to have count #{@expected_count}, got #{actual_count}"
          elsif @expected_match
            mismatches = @expected_match.reject { |key, value| data.is_a?(Hash) && data[key.to_s] == value }
            "expected data at #{path.inspect} to match #{@expected_match.inspect}, " \
              "but #{mismatches.inspect} did not match. Got: #{data.inspect}"
          elsif @expected_include
            "expected data at #{path.inspect} to include #{@expected_include.inspect}, got: #{data.inspect}"
          elsif path.empty?
            "expected result to have data, but got: #{result.inspect}"
          elsif @expected_value
            "expected data at #{path.inspect} to be #{@expected_value.inspect}, got #{data.inspect}"
          else
            "expected to find data at path #{path.inspect}, but result was: #{result["data"].inspect}"
          end
        end

        def dig_data(data, path)
          path.reduce(data) do |current, key|
            return nil if current.nil?

            current.is_a?(Hash) ? current[key.to_s] : nil
          end
        end
      end

      # Matcher for checking if GraphQL result has errors
      #
      # @example
      #   expect(result).to have_graphql_errors
      #   expect(result).to have_graphql_errors(2)  # Exactly 2 errors
      #   expect(result).to have_graphql_error.with_message("Not found")
      #   expect(result).to have_graphql_error.with_extensions(code: "NOT_FOUND")
      #   expect(result).to have_graphql_error.at_path(["user", "email"])
      #   expect { execute_query }.to have_graphql_errors
      #
      RSpec::Matchers.define :have_graphql_errors do |expected_count = nil|
        match do |result_or_block|
          @expected_count = expected_count
          if result_or_block.is_a?(Proc)
            begin
              result_or_block.call
              @raised_error = false
              false
            rescue StandardError => e
              @raised_error = true
              @error = e
              true
            end
          else
            @result = result_or_block
            errors = result_or_block["errors"]
            return false if errors.nil? || (errors.is_a?(Array) && errors.empty?)

            # Check for exact error count if specified
            if @expected_count
              @actual_count = errors.is_a?(Array) ? errors.length : 0
              return false unless @actual_count == @expected_count
            end

            # Check for specific message
            if @expected_message
              return errors.any? { |error| error["message"]&.include?(@expected_message) }
            end

            # Check for specific extensions
            if @expected_extensions
              return errors.any? do |error|
                extensions = error["extensions"]
                extensions && @expected_extensions.all? { |key, value| extensions[key.to_s] == value }
              end
            end

            # Check for specific path
            if @expected_path
              return errors.any? { |error| error["path"] == @expected_path }
            end

            true
          end
        end

        chain :with_message do |expected_message|
          @expected_message = expected_message
        end

        chain :with_extensions do |expected_extensions|
          @expected_extensions = expected_extensions
        end

        chain :at_path do |expected_path|
          @expected_path = expected_path
        end

        failure_message do
          if @raised_error
            "expected no errors, but got: #{@error.message}"
          elsif @expected_count
            "expected exactly #{@expected_count} error(s), but got #{@actual_count}"
          elsif @expected_message
            errors = @result["errors"] || []
            messages = errors.map { |e| e["message"] }
            "expected errors to include message containing #{@expected_message.inspect}, " \
              "got messages: #{messages.inspect}"
          elsif @expected_extensions
            errors = @result["errors"] || []
            extensions = errors.map { |e| e["extensions"] }
            "expected errors to have extensions #{@expected_extensions.inspect}, " \
              "got extensions: #{extensions.inspect}"
          elsif @expected_path
            errors = @result["errors"] || []
            paths = errors.map { |e| e["path"] }
            "expected errors at path #{@expected_path.inspect}, got paths: #{paths.inspect}"
          else
            "expected GraphQL result to have errors, but it succeeded"
          end
        end

        supports_block_expectations
      end

      # Alias for singular form
      RSpec::Matchers.alias_matcher :have_graphql_error, :have_graphql_errors

      # Matcher for checking if GraphQL query succeeds
      #
      # @example
      #   expect(result).to succeed_graphql
      #
      RSpec::Matchers.define :succeed_graphql do
        match do |result|
          result["errors"].nil? || result["errors"].empty?
        end

        failure_message do |result|
          "expected GraphQL query to succeed, but got errors: #{result["errors"]}"
        end
      end

      # Matcher for checking if GraphQL result has a specific field
      #
      # @example
      #   expect(result.data).to have_graphql_field("id")
      #   expect(result.data).to have_graphql_field(:name)
      #
      RSpec::Matchers.define :have_graphql_field do |field_name|
        match do |data|
          data.is_a?(Hash) && data.key?(field_name.to_s)
        end

        failure_message do |data|
          "expected data to have field #{field_name.inspect}, but data was: #{data.inspect}"
        end
      end

      # Matcher for checking if GraphQL result has multiple fields with specific values
      #
      # @example
      #   expect(result.data).to have_graphql_fields(id: "123", name: "John")
      #
      RSpec::Matchers.define :have_graphql_fields do |expected_fields|
        match do |data|
          return false unless data.is_a?(Hash)

          expected_fields.all? do |field, value|
            data.key?(field.to_s) && data[field.to_s] == value
          end
        end

        failure_message do |data|
          missing_or_wrong = expected_fields.reject do |field, value|
            data.key?(field.to_s) && data[field.to_s] == value
          end

          "expected data to have fields #{expected_fields.inspect}, " \
            "but #{missing_or_wrong.inspect} did not match. " \
            "Data was: #{data.inspect}"
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include Zenspec::Matchers::GraphQLMatchers
end
