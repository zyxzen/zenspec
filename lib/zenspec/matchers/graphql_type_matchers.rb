# frozen_string_literal: true

require "rspec/expectations"

module Zenspec
  module Matchers
    module GraphQLTypeMatchers
      # Matcher for checking if a GraphQL type has a specific field with type and arguments
      #
      # @example
      #   expect(UserType).to have_field(:id).of_type("ID!")
      #   expect(UserType).to have_field(:name).of_type("String!")
      #   expect(UserType).to have_field(:posts).of_type("[Post!]!")
      #   expect(UserType).to have_field(:posts).with_argument(:limit, "Int")
      #
      RSpec::Matchers.define :have_field do |field_name|
        match do |type|
          @field_name = field_name.to_s
          @type = type

          # Get the field from the type
          @field = get_field(type, @field_name)
          return false unless @field

          # Check field type if specified
          if @expected_type
            actual_type = field_type_string(@field)
            return false unless actual_type == @expected_type
          end

          # Check arguments if specified
          if @expected_arguments && @expected_arguments.any?
            @expected_arguments.all? do |arg_name, arg_type|
              check_argument(arg_name, arg_type)
            end
          else
            true
          end
        end

        chain :of_type do |expected_type|
          @expected_type = expected_type
        end

        chain :with_argument do |arg_name, arg_type|
          @expected_arguments ||= {}
          @expected_arguments[arg_name.to_s] = arg_type
        end

        failure_message do
          if !@field
            "expected #{type_name(@type)} to have field #{@field_name.inspect}, but it does not"
          elsif @expected_type && field_type_string(@field) != @expected_type
            "expected field #{@field_name.inspect} to have type #{@expected_type.inspect}, " \
              "got #{field_type_string(@field).inspect}"
          elsif @expected_arguments
            missing_or_wrong = find_mismatched_arguments
            "expected field #{@field_name.inspect} to have arguments #{@expected_arguments.inspect}, " \
              "but #{missing_or_wrong.inspect} did not match"
          end
        end

        private

        def get_field(type, field_name)
          if type.respond_to?(:fields)
            type.fields[field_name]
          elsif type.respond_to?(:get_field)
            type.get_field(field_name)
          end
        end

        def field_type_string(field)
          return nil unless field

          type = field.type
          type_to_string(type)
        end

        def type_to_string(type)
          case type
          when GraphQL::Schema::NonNull
            "#{type_to_string(type.of_type)}!"
          when GraphQL::Schema::List
            "[#{type_to_string(type.of_type)}]"
          when GraphQL::Schema::Member
            type.graphql_name
          else
            # Handle wrapped types from graphql-ruby
            if type.respond_to?(:unwrap)
              unwrapped = type.unwrap
              base_name = unwrapped.respond_to?(:graphql_name) ? unwrapped.graphql_name : unwrapped.to_s

              # Build the type string with wrappers
              result = base_name
              result = "[#{result}]" if list?(type)
              result = "#{result}!" if non_null?(type)
              result
            elsif type.respond_to?(:graphql_name)
              type.graphql_name
            else
              type.to_s
            end
          end
        end

        def list?(type)
          type.is_a?(GraphQL::Schema::List) ||
            (type.respond_to?(:list?) && type.list?)
        end

        def non_null?(type)
          type.is_a?(GraphQL::Schema::NonNull) ||
            (type.respond_to?(:non_null?) && type.non_null?)
        end

        def check_argument(arg_name, expected_type)
          return false unless @field.respond_to?(:arguments)

          arg = @field.arguments[arg_name]
          return false unless arg

          if expected_type
            actual_type = type_to_string(arg.type)
            actual_type == expected_type
          else
            true
          end
        end

        def find_mismatched_arguments
          return {} unless @expected_arguments

          @expected_arguments.select do |arg_name, expected_type|
            !check_argument(arg_name, expected_type)
          end
        end

        def type_name(type)
          if type.respond_to?(:graphql_name)
            type.graphql_name
          elsif type.respond_to?(:name)
            type.name
          else
            type.to_s
          end
        end
      end

      # Matcher for checking if an enum has specific values
      #
      # @example
      #   expect(StatusEnum).to have_enum_values("ACTIVE", "INACTIVE", "PENDING")
      #
      RSpec::Matchers.define :have_enum_values do |*expected_values|
        match do |enum_type|
          @enum_type = enum_type
          @expected_values = expected_values.map(&:to_s)

          actual_values = get_enum_values(enum_type)
          @actual_values = actual_values

          @expected_values.all? { |value| actual_values.include?(value) }
        end

        failure_message do
          missing_values = @expected_values - @actual_values
          "expected #{enum_name(@enum_type)} to have values #{@expected_values.inspect}, " \
            "but #{missing_values.inspect} were missing. " \
            "Actual values: #{@actual_values.inspect}"
        end

        private

        def get_enum_values(enum_type)
          if enum_type.respond_to?(:values)
            # GraphQL::EnumType or GraphQL::Schema::Enum
            if enum_type.values.is_a?(Hash)
              enum_type.values.keys.map(&:to_s)
            elsif enum_type.values.is_a?(Array)
              enum_type.values.map { |v| v.respond_to?(:graphql_name) ? v.graphql_name : v.to_s }
            else
              []
            end
          else
            []
          end
        end

        def enum_name(enum_type)
          if enum_type.respond_to?(:graphql_name)
            enum_type.graphql_name
          elsif enum_type.respond_to?(:name)
            enum_type.name
          else
            enum_type.to_s
          end
        end
      end

      # Matcher for checking if a field has a specific argument with type
      #
      # @example
      #   expect(UserType.fields["posts"]).to have_argument(:limit).of_type("Int")
      #   expect(UserType.fields["posts"]).to have_argument(:status).of_type("Status!")
      #   expect(QueryType.fields["users"]).to have_argument(:filter).of_type("UserFilterInput")
      #
      RSpec::Matchers.define :have_argument do |arg_name|
        match do |field|
          @field = field
          @arg_name = arg_name.to_s

          # Get the argument
          @argument = get_argument(field, @arg_name)
          return false unless @argument

          # Check argument type if specified
          if @expected_type
            actual_type = argument_type_string(@argument)
            return false unless actual_type == @expected_type
          end

          true
        end

        chain :of_type do |expected_type|
          @expected_type = expected_type
        end

        failure_message do
          if !@argument
            field_name = @field.respond_to?(:name) ? @field.name : @field.to_s
            "expected field #{field_name.inspect} to have argument #{@arg_name.inspect}, but it does not"
          elsif @expected_type && argument_type_string(@argument) != @expected_type
            "expected argument #{@arg_name.inspect} to have type #{@expected_type.inspect}, " \
              "got #{argument_type_string(@argument).inspect}"
          end
        end

        private

        def get_argument(field, arg_name)
          return nil unless field.respond_to?(:arguments)

          field.arguments[arg_name]
        end

        def argument_type_string(argument)
          return nil unless argument

          type = argument.type
          type_to_string(type)
        end

        def type_to_string(type)
          case type
          when GraphQL::Schema::NonNull
            "#{type_to_string(type.of_type)}!"
          when GraphQL::Schema::List
            "[#{type_to_string(type.of_type)}]"
          when GraphQL::Schema::Member
            type.graphql_name
          else
            # Handle wrapped types from graphql-ruby
            if type.respond_to?(:unwrap)
              unwrapped = type.unwrap
              base_name = unwrapped.respond_to?(:graphql_name) ? unwrapped.graphql_name : unwrapped.to_s

              # Build the type string with wrappers
              result = base_name
              result = "[#{result}]" if list?(type)
              result = "#{result}!" if non_null?(type)
              result
            elsif type.respond_to?(:graphql_name)
              type.graphql_name
            else
              type.to_s
            end
          end
        end

        def list?(type)
          type.is_a?(GraphQL::Schema::List) ||
            (type.respond_to?(:list?) && type.list?)
        end

        def non_null?(type)
          type.is_a?(GraphQL::Schema::NonNull) ||
            (type.respond_to?(:non_null?) && type.non_null?)
        end
      end

      # Matcher for checking if a schema has a specific query field
      #
      # @example
      #   expect(schema).to have_query(:user).with_argument(:id, "ID!")
      #   expect(schema).to have_query(:users).of_type("[User!]!")
      #
      RSpec::Matchers.define :have_query do |query_name|
        match do |schema|
          @schema = schema
          @query_name = query_name.to_s

          # Get the query type
          query_type = get_query_type(schema)
          return false unless query_type

          # Get the field
          @field = get_field(query_type, @query_name)
          return false unless @field

          # Check field type if specified
          if @expected_type
            actual_type = field_type_string(@field)
            return false unless actual_type == @expected_type
          end

          # Check arguments if specified
          if @expected_arguments && @expected_arguments.any?
            @expected_arguments.all? do |arg_name, arg_type|
              check_argument(arg_name, arg_type)
            end
          else
            true
          end
        end

        chain :of_type do |expected_type|
          @expected_type = expected_type
        end

        chain :with_argument do |arg_name, arg_type|
          @expected_arguments ||= {}
          @expected_arguments[arg_name.to_s] = arg_type
        end

        failure_message do
          if !get_query_type(@schema)
            "expected schema to have a query type, but it does not"
          elsif !@field
            "expected schema query to have field #{@query_name.inspect}, but it does not"
          elsif @expected_type && field_type_string(@field) != @expected_type
            "expected query field #{@query_name.inspect} to have type #{@expected_type.inspect}, " \
              "got #{field_type_string(@field).inspect}"
          elsif @expected_arguments
            "expected query field #{@query_name.inspect} to have arguments #{@expected_arguments.inspect}"
          end
        end

        private

        def get_query_type(schema)
          schema.respond_to?(:query) ? schema.query : nil
        end

        def get_field(type, field_name)
          if type.respond_to?(:fields)
            type.fields[field_name]
          elsif type.respond_to?(:get_field)
            type.get_field(field_name)
          end
        end

        def field_type_string(field)
          return nil unless field

          type = field.type
          type_to_string(type)
        end

        def type_to_string(type)
          case type
          when GraphQL::Schema::NonNull
            "#{type_to_string(type.of_type)}!"
          when GraphQL::Schema::List
            "[#{type_to_string(type.of_type)}]"
          when GraphQL::Schema::Member
            type.graphql_name
          else
            if type.respond_to?(:unwrap)
              unwrapped = type.unwrap
              base_name = unwrapped.respond_to?(:graphql_name) ? unwrapped.graphql_name : unwrapped.to_s

              result = base_name
              result = "[#{result}]" if list?(type)
              result = "#{result}!" if non_null?(type)
              result
            elsif type.respond_to?(:graphql_name)
              type.graphql_name
            else
              type.to_s
            end
          end
        end

        def list?(type)
          type.is_a?(GraphQL::Schema::List) ||
            (type.respond_to?(:list?) && type.list?)
        end

        def non_null?(type)
          type.is_a?(GraphQL::Schema::NonNull) ||
            (type.respond_to?(:non_null?) && type.non_null?)
        end

        def check_argument(arg_name, expected_type)
          return false unless @field.respond_to?(:arguments)

          arg = @field.arguments[arg_name]
          return false unless arg

          if expected_type
            actual_type = type_to_string(arg.type)
            actual_type == expected_type
          else
            true
          end
        end
      end

      # Matcher for checking if a schema has a specific mutation field
      #
      # @example
      #   expect(schema).to have_mutation(:createUser).with_argument(:input, "CreateUserInput!")
      #   expect(schema).to have_mutation(:deleteUser).of_type("DeleteUserPayload!")
      #
      RSpec::Matchers.define :have_mutation do |mutation_name|
        match do |schema|
          @schema = schema
          @mutation_name = mutation_name.to_s

          # Get the mutation type
          mutation_type = get_mutation_type(schema)
          return false unless mutation_type

          # Get the field
          @field = get_field(mutation_type, @mutation_name)
          return false unless @field

          # Check field type if specified
          if @expected_type
            actual_type = field_type_string(@field)
            return false unless actual_type == @expected_type
          end

          # Check arguments if specified
          if @expected_arguments && @expected_arguments.any?
            @expected_arguments.all? do |arg_name, arg_type|
              check_argument(arg_name, arg_type)
            end
          else
            true
          end
        end

        chain :of_type do |expected_type|
          @expected_type = expected_type
        end

        chain :with_argument do |arg_name, arg_type|
          @expected_arguments ||= {}
          @expected_arguments[arg_name.to_s] = arg_type
        end

        failure_message do
          if !get_mutation_type(@schema)
            "expected schema to have a mutation type, but it does not"
          elsif !@field
            "expected schema mutation to have field #{@mutation_name.inspect}, but it does not"
          elsif @expected_type && field_type_string(@field) != @expected_type
            "expected mutation field #{@mutation_name.inspect} to have type #{@expected_type.inspect}, " \
              "got #{field_type_string(@field).inspect}"
          elsif @expected_arguments
            "expected mutation field #{@mutation_name.inspect} to have arguments #{@expected_arguments.inspect}"
          end
        end

        private

        def get_mutation_type(schema)
          schema.respond_to?(:mutation) ? schema.mutation : nil
        end

        def get_field(type, field_name)
          if type.respond_to?(:fields)
            type.fields[field_name]
          elsif type.respond_to?(:get_field)
            type.get_field(field_name)
          end
        end

        def field_type_string(field)
          return nil unless field

          type = field.type
          type_to_string(type)
        end

        def type_to_string(type)
          case type
          when GraphQL::Schema::NonNull
            "#{type_to_string(type.of_type)}!"
          when GraphQL::Schema::List
            "[#{type_to_string(type.of_type)}]"
          when GraphQL::Schema::Member
            type.graphql_name
          else
            if type.respond_to?(:unwrap)
              unwrapped = type.unwrap
              base_name = unwrapped.respond_to?(:graphql_name) ? unwrapped.graphql_name : unwrapped.to_s

              result = base_name
              result = "[#{result}]" if list?(type)
              result = "#{result}!" if non_null?(type)
              result
            elsif type.respond_to?(:graphql_name)
              type.graphql_name
            else
              type.to_s
            end
          end
        end

        def list?(type)
          type.is_a?(GraphQL::Schema::List) ||
            (type.respond_to?(:list?) && type.list?)
        end

        def non_null?(type)
          type.is_a?(GraphQL::Schema::NonNull) ||
            (type.respond_to?(:non_null?) && type.non_null?)
        end

        def check_argument(arg_name, expected_type)
          return false unless @field.respond_to?(:arguments)

          arg = @field.arguments[arg_name]
          return false unless arg

          if expected_type
            actual_type = type_to_string(arg.type)
            actual_type == expected_type
          else
            true
          end
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include Zenspec::Matchers::GraphQLTypeMatchers
end
