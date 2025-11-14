# frozen_string_literal: true

module Zenspec
  module Helpers
    module GraphQLHelpers
      # Execute a GraphQL query with variables and context
      #
      # @param query [String] The GraphQL query string
      # @param variables [Hash] Query variables
      # @param context [Hash] Execution context
      # @param schema [GraphQL::Schema] Optional schema (defaults to AppSchema)
      # @return [GraphQL::Query::Result] The query result
      #
      # @example
      #   result = graphql_execute(query, variables: { id: "123" }, context: { current_user: user })
      #   expect(result).to succeed_graphql
      #
      def graphql_execute(query, variables: {}, context: {}, schema: nil)
        schema_class = schema || default_schema
        raise "No GraphQL schema found. Please define AppSchema or pass schema: argument" unless schema_class

        schema_class.execute(
          query,
          variables: variables,
          context: context
        )
      end

      # Execute a GraphQL query with a user automatically added to context
      #
      # @param user [Object] The user object to add to context
      # @param query [String] The GraphQL query string
      # @param variables [Hash] Query variables
      # @param context [Hash] Additional context (merged with user context)
      # @param schema [GraphQL::Schema] Optional schema (defaults to AppSchema)
      # @param context_key [Symbol] The key to use for the user in context (defaults to :current_user)
      # @return [GraphQL::Query::Result] The query result
      #
      # @example
      #   result = graphql_execute_as(user, query, variables: { id: "123" })
      #   expect(result).to succeed_graphql
      #
      def graphql_execute_as(user, query, variables: {}, context: {}, schema: nil, context_key: :current_user)
        merged_context = context.merge(context_key => user)
        graphql_execute(query, variables: variables, context: merged_context, schema: schema)
      end

      # Execute a GraphQL mutation with input
      #
      # @param mutation [String] The GraphQL mutation string
      # @param input [Hash] Mutation input variables
      # @param context [Hash] Execution context
      # @param schema [GraphQL::Schema] Optional schema (defaults to AppSchema)
      # @return [GraphQL::Query::Result] The mutation result
      #
      # @example
      #   result = graphql_mutate(mutation, input: { name: "John", email: "john@example.com" })
      #   expect(result).to succeed_graphql
      #
      def graphql_mutate(mutation, input: {}, context: {}, schema: nil)
        graphql_execute(mutation, variables: { input: input }, context: context, schema: schema)
      end

      # Execute a GraphQL mutation as a specific user
      #
      # @param user [Object] The user object to add to context
      # @param mutation [String] The GraphQL mutation string
      # @param input [Hash] Mutation input variables
      # @param context [Hash] Additional context (merged with user context)
      # @param schema [GraphQL::Schema] Optional schema (defaults to AppSchema)
      # @param context_key [Symbol] The key to use for the user in context (defaults to :current_user)
      # @return [GraphQL::Query::Result] The mutation result
      #
      # @example
      #   result = graphql_mutate_as(user, mutation, input: { name: "John" })
      #   expect(result).to succeed_graphql
      #
      def graphql_mutate_as(user, mutation, input: {}, context: {}, schema: nil, context_key: :current_user)
        merged_context = context.merge(context_key => user)
        graphql_mutate(mutation, input: input, context: merged_context, schema: schema)
      end

      private

      def default_schema
        # Try to find a schema in common locations
        if defined?(AppSchema)
          AppSchema
        elsif defined?(Schema)
          Schema
        elsif defined?(GraphqlSchema)
          GraphqlSchema
        elsif defined?(ApplicationSchema)
          ApplicationSchema
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include Zenspec::Helpers::GraphQLHelpers
end
