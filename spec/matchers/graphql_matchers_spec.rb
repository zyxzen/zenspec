# frozen_string_literal: true

require "graphql"

# Test to verify GraphQL query matchers work correctly
RSpec.describe "GraphQL Query Matchers" do
  # Define a simple GraphQL schema for testing
  class TestUserType < GraphQL::Schema::Object
    field :id, ID, null: false
    field :name, String, null: false
    field :email, String, null: false
  end

  class TestQueryType < GraphQL::Schema::Object
    field :user, TestUserType, null: false do
      argument :id, ID, required: true
    end

    def user(id:)
      raise GraphQL::ExecutionError, "User not found" unless id == "1"

      { id: "1", name: "Test User", email: "test@example.com" }
    end
  end

  class TestSchema < GraphQL::Schema
    query TestQueryType
  end

  let(:success_query) do
    <<~GQL
      query GetUser($id: ID!) {
        user(id: $id) {
          id
          name
          email
        }
      }
    GQL
  end

  let(:error_query) do
    <<~GQL
      query GetUser($id: ID!) {
        user(id: $id) {
          id
          name
        }
      }
    GQL
  end

  describe "have_graphql_data matcher" do
    let(:result) { TestSchema.execute(success_query, variables: { id: "1" }) }

    it "matches when data exists" do
      expect(result).to have_graphql_data
    end

    it "matches data at path" do
      expect(result).to have_graphql_data("user")
      expect(result).to have_graphql_data("user", "id")
    end

    it "matches with value" do
      expect(result).to have_graphql_data("user", "name").with_value("Test User")
    end

    it "fails when data does not exist" do
      expect(result).not_to have_graphql_data("nonexistent")
    end

    it "matches with partial matching" do
      expect(result).to have_graphql_data("user").matching(
        id: "1",
        name: "Test User"
      )
    end

    it "matches with that_includes" do
      expect(result).to have_graphql_data("user").that_includes(name: "Test User")
    end

    it "matches with that_is_present" do
      expect(result).to have_graphql_data("user").that_is_present
    end
  end

  describe "have_graphql_errors matcher" do
    it "matches when errors exist" do
      result = TestSchema.execute(error_query, variables: { id: "999" })
      expect(result).to have_graphql_errors
    end

    it "fails when no errors exist" do
      result = TestSchema.execute(success_query, variables: { id: "1" })
      expect(result).not_to have_graphql_errors
    end
  end

  describe "succeed_graphql matcher" do
    let(:result) { TestSchema.execute(success_query, variables: { id: "1" }) }

    it "matches successful query" do
      expect(result).to succeed_graphql
    end

    it "fails when query has errors" do
      error_result = TestSchema.execute(error_query, variables: { id: "999" })
      expect(error_result).not_to succeed_graphql
    end
  end

  describe "have_graphql_field matcher" do
    let(:result) { TestSchema.execute(success_query, variables: { id: "1" }) }
    let(:data) { result.dig("data", "user") }

    it "matches when field exists (string)" do
      expect(data).to have_graphql_field("name")
    end

    it "matches when field exists (symbol)" do
      expect(data).to have_graphql_field(:id)
    end

    it "fails when field does not exist" do
      expect(data).not_to have_graphql_field("nonexistent")
    end
  end

  describe "have_graphql_fields matcher" do
    let(:result) { TestSchema.execute(success_query, variables: { id: "1" }) }
    let(:data) { result.dig("data", "user") }

    it "matches field values" do
      expect(data).to have_graphql_fields(
        id: "1",
        name: "Test User",
        email: "test@example.com"
      )
    end

    it "fails when fields do not match" do
      expect(data).not_to have_graphql_fields(
        id: "1",
        name: "Wrong Name"
      )
    end
  end
end
