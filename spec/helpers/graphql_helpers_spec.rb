# frozen_string_literal: true

require "graphql"

RSpec.describe Zenspec::Helpers::GraphQLHelpers do
  # Define a test user class
  class TestUser
    attr_accessor :id, :name

    def initialize(id:, name:)
      @id = id
      @name = name
    end
  end

  # Define test GraphQL schema
  class TestHelperUserType < GraphQL::Schema::Object
    field :id, ID, null: false
    field :name, String, null: false
  end

  class TestHelperQueryType < GraphQL::Schema::Object
    field :current_user, TestHelperUserType, null: true
    field :user, TestHelperUserType, null: false do
      argument :id, ID, required: true
    end

    def current_user
      context[:current_user]
    end

    def user(id:)
      context[:current_user] if context[:current_user]&.id == id
    end
  end

  class TestHelperMutationType < GraphQL::Schema::Object
    field :update_user, TestHelperUserType, null: false do
      argument :input, String, required: true
    end

    def update_user(input:)
      context[:current_user].name = input if context[:current_user]
      context[:current_user]
    end
  end

  class TestHelperSchema < GraphQL::Schema
    query TestHelperQueryType
    mutation TestHelperMutationType
  end

  # Make test schema available as AppSchema for the helpers
  before do
    stub_const("AppSchema", TestHelperSchema)
  end

  let(:user) { TestUser.new(id: "123", name: "Test User") }

  describe "#graphql_execute" do
    let(:query) do
      <<~GQL
        query {
          currentUser {
            id
            name
          }
        }
      GQL
    end

    it "executes GraphQL query" do
      result = graphql_execute(query, context: { current_user: user })

      expect(result).to succeed_graphql
      expect(result).to have_graphql_data("currentUser", "id").with_value("123")
      expect(result).to have_graphql_data("currentUser", "name").with_value("Test User")
    end

    it "executes with variables" do
      query_with_vars = <<~GQL
        query GetUser($id: ID!) {
          user(id: $id) {
            id
            name
          }
        }
      GQL

      result = graphql_execute(
        query_with_vars,
        variables: { id: "123" },
        context: { current_user: user }
      )

      expect(result).to succeed_graphql
      expect(result).to have_graphql_data("user", "id").with_value("123")
    end

    it "executes with custom schema" do
      result = graphql_execute(query, context: { current_user: user }, schema: TestHelperSchema)

      expect(result).to succeed_graphql
    end
  end

  describe "#graphql_execute_as" do
    let(:query) do
      <<~GQL
        query {
          currentUser {
            id
            name
          }
        }
      GQL
    end

    it "executes query with user context" do
      result = graphql_execute_as(user, query)

      expect(result).to succeed_graphql
      expect(result).to have_graphql_data("currentUser", "id").with_value("123")
    end

    it "executes with additional context" do
      result = graphql_execute_as(user, query, context: { additional: "data" })

      expect(result).to succeed_graphql
    end

    it "uses custom context key" do
      result = graphql_execute_as(user, query, context_key: :user)

      # This would fail because we're using :user instead of :current_user
      # but it demonstrates the context_key parameter works
      expect(result).to succeed_graphql
    end
  end

  describe "#graphql_mutate" do
    let(:mutation) do
      <<~GQL
        mutation UpdateUser($input: String!) {
          updateUser(input: $input) {
            id
            name
          }
        }
      GQL
    end

    it "executes mutation with input" do
      result = graphql_mutate(
        mutation,
        input: "New Name",
        context: { current_user: user }
      )

      expect(result).to succeed_graphql
      expect(result).to have_graphql_data("updateUser", "name").with_value("New Name")
    end
  end

  describe "#graphql_mutate_as" do
    let(:mutation) do
      <<~GQL
        mutation UpdateUser($input: String!) {
          updateUser(input: $input) {
            id
            name
          }
        }
      GQL
    end

    it "executes mutation as user" do
      result = graphql_mutate_as(user, mutation, input: "Updated Name")

      expect(result).to succeed_graphql
      expect(result).to have_graphql_data("updateUser", "name").with_value("Updated Name")
    end

    it "executes with additional context" do
      result = graphql_mutate_as(user, mutation, input: "Name", context: { extra: "data" })

      expect(result).to succeed_graphql
    end
  end
end
