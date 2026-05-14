# frozen_string_literal: true

require "rspec/expectations"

module Zenspec
  module Matchers
    module InteractorMatchers
      # Matcher for checking if an interactor succeeds
      #
      # @example
      #   expect(result).to succeed
      #   expect(result).to succeed.with_data(expected_value)
      #   expect(result).to succeed.with_data_type(SomeClass)
      #   expect(result).to succeed.with_persisted_data
      #   expect(result).to succeed.with_context(:key, value)
      #   expect(MyInteractor).to succeed.with_context(:user, user)
      #
      RSpec::Matchers.define :succeed do
        match do |actual|
          @result = get_result(actual)
          return false if @result.failure?

          return false if !@expected_data.nil? && @result.data != @expected_data

          if @check_persisted_data
            @persisted_failure = persisted_data_failure(@result.data)
            return false if @persisted_failure
          end

          return false if @expected_data_type && !@result.data.is_a?(@expected_data_type)

          if @context_checks
            @context_checks.all? do |key, value|
              @result.public_send(key) == value
            end
          else
            true
          end
        end

        chain :with_data do |expected_data|
          @expected_data = expected_data
        end

        chain :with_data_type do |expected_type|
          @expected_data_type = expected_type
        end

        chain :with_persisted_data do
          @check_persisted_data = true
        end

        chain :with_context do |key, value|
          @context_checks ||= {}
          @context_checks[key] = value
        end

        failure_message do
          if @result.failure?
            "expected interactor to succeed, but it failed with errors: #{@result.errors}"
          elsif @expected_data && @result.data != @expected_data
            "expected data to be #{@expected_data.inspect}, got #{@result.data.inspect}"
          elsif @check_persisted_data && @persisted_failure
            @persisted_failure
          elsif @expected_data_type && !@result.data.is_a?(@expected_data_type)
            "expected data to be a kind of #{@expected_data_type}, got #{@result.data.class} (#{@result.data.inspect})"
          elsif @context_checks
            failed_checks = @context_checks.reject { |key, value| @result.public_send(key) == value }
            "expected context to match #{@context_checks.inspect}, but #{failed_checks.inspect} did not match"
          end
        end

        def get_result(actual)
          if actual.is_a?(Class) && actual.ancestors.include?(Interactor)
            actual.call
          else
            actual
          end
        end

        def persisted_data_failure(data)
          if data.nil?
            "expected context.data to be a persisted record, but it was nil"
          elsif data.respond_to?(:present?) && !data.present?
            "expected context.data to be a persisted record, but it was blank: #{data.inspect}"
          elsif !data.respond_to?(:persisted?)
            "expected context.data to respond to :persisted?, got #{data.class} (#{data.inspect})"
          elsif !data.persisted?
            "expected context.data to be persisted, but #{data.inspect} was not"
          end
        end
      end

      # Matcher for checking if an interactor fails
      #
      # @example
      #   expect(result).to fail_interactor
      #   expect(result).to fail_interactor.with_error("invalid_input")
      #   expect(result).to fail_interactor.with_errors("error1", "error2")
      #   expect(MyInteractor).to fail_interactor.with_error("not_found")
      #
      RSpec::Matchers.define :fail_interactor do
        match do |actual|
          @result = get_result(actual)
          return false if @result.success?

          if @expected_error_codes && !@expected_error_codes.empty?
            actual_codes = error_codes(@result)
            @expected_error_codes.all? { |code| actual_codes.include?(code) }
          else
            true
          end
        end

        chain :with_error do |error_code|
          @expected_error_codes ||= []
          @expected_error_codes << error_code
        end

        chain :with_errors do |*error_codes|
          @expected_error_codes ||= []
          @expected_error_codes.concat(error_codes)
        end

        failure_message do
          if @result.success?
            "expected interactor to fail, but it succeeded"
          else
            actual_codes = error_codes(@result)
            "expected errors to include #{@expected_error_codes.inspect}, got #{actual_codes.inspect}"
          end
        end

        def get_result(actual)
          if actual.is_a?(Class) && actual.ancestors.include?(Interactor)
            actual.call
          else
            actual
          end
        end

        def error_codes(result)
          return [] unless result.errors

          if result.errors.is_a?(Array)
            result.errors.map { |e| e.is_a?(Hash) ? e[:code] : e.to_s }.compact
          else
            []
          end
        end
      end

      # Matcher for checking if a result has a specific error code
      #
      # @example
      #   expect(result).to have_error_code("invalid_input")
      #
      RSpec::Matchers.define :have_error_code do |expected_code|
        match do |result|
          error_codes(result).include?(expected_code)
        end

        failure_message do |result|
          "expected errors to include #{expected_code.inspect}, got #{error_codes(result).inspect}"
        end

        def error_codes(result)
          return [] unless result.errors

          if result.errors.is_a?(Array)
            result.errors.map { |e| e.is_a?(Hash) ? e[:code] : e.to_s }.compact
          else
            []
          end
        end
      end

      # Matcher for checking if a result has multiple error codes
      #
      # @example
      #   expect(result).to have_error_codes("error1", "error2")
      #
      RSpec::Matchers.define :have_error_codes do |*expected_codes|
        match do |result|
          actual_codes = error_codes(result)
          expected_codes.all? { |code| actual_codes.include?(code) }
        end

        failure_message do |result|
          "expected errors to include #{expected_codes.inspect}, got #{error_codes(result).inspect}"
        end

        def error_codes(result)
          return [] unless result.errors

          if result.errors.is_a?(Array)
            result.errors.map { |e| e.is_a?(Hash) ? e[:code] : e.to_s }.compact
          else
            []
          end
        end
      end

      # Matcher for checking if context has a specific key/value
      #
      # @example
      #   expect(result).to set_context(:data)
      #   expect(result).to set_context(:data, expected_value)
      #   expect(result).to set_context(:user).to(user)
      #
      RSpec::Matchers.define :set_context do |key, value = nil|
        match do |result|
          return false unless result.respond_to?(key)

          actual_value = result.public_send(key)

          if @expected_value
            actual_value == @expected_value
          elsif !value.nil?
            actual_value == value
          else
            !actual_value.nil?
          end
        end

        chain :to do |expected_value|
          @expected_value = expected_value
        end

        failure_message do |result|
          if !result.respond_to?(key)
            "expected context to have key #{key.inspect}"
          elsif @expected_value || !value.nil?
            expected = @expected_value || value
            "expected context[#{key.inspect}] to be #{expected.inspect}, got #{result.public_send(key).inspect}"
          else
            "expected context[#{key.inspect}] to be set"
          end
        end
      end

      # Matcher for checking that an ActiveRecord record has been destroyed
      #
      # Passes when either +record.destroyed?+ is true, or
      # +record.class.exists?(record.id)+ returns false.
      #
      # @example
      #   expect(result).to destroy_record(record)
      #   expect(MyDestroyInteractor).to destroy_record(record)
      #
      RSpec::Matchers.define :destroy_record do |record|
        match do |actual|
          actual.call if actual.is_a?(Class) && actual.ancestors.include?(Interactor)

          record_destroyed?(record)
        end

        match_when_negated do |actual|
          actual.call if actual.is_a?(Class) && actual.ancestors.include?(Interactor)

          !record_destroyed?(record)
        end

        failure_message do
          "expected #{record.inspect} to be destroyed, but it still exists"
        end

        failure_message_when_negated do
          "expected #{record.inspect} not to be destroyed, but it was"
        end

        def record_destroyed?(record)
          return true if record.respond_to?(:destroyed?) && record.destroyed?
          return true if record.class.respond_to?(:exists?) && !record.class.exists?(record.id)

          false
        end
      end

      # Matcher for checking that an ActiveRecord record has been updated with
      # the given attributes after the interactor runs.
      #
      # @example
      #   expect(result).to update_record(record).with(name: "new", is_active: true)
      #   expect(MyUpdateInteractor).to update_record(record).with(name: "new")
      #
      RSpec::Matchers.define :update_record do |record|
        match do |actual|
          actual.call if actual.is_a?(Class) && actual.ancestors.include?(Interactor)

          record.reload if record.respond_to?(:reload)

          @expected_attrs ||= {}
          @mismatches = @expected_attrs.each_with_object({}) do |(key, expected), memo|
            actual_value = record.public_send(key)
            memo[key] = { expected: expected, actual: actual_value } if actual_value != expected
          end

          @mismatches.empty?
        end

        chain :with do |expected_attrs|
          @expected_attrs = expected_attrs
        end

        failure_message do
          details = @mismatches.map do |key, values|
            "#{key}: expected #{values[:expected].inspect}, got #{values[:actual].inspect}"
          end.join("; ")
          "expected #{record.inspect} to be updated with #{@expected_attrs.inspect}, but #{details}"
        end

        failure_message_when_negated do
          "expected #{record.inspect} not to be updated with #{@expected_attrs.inspect}, but it was"
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include Zenspec::Matchers::InteractorMatchers
end
