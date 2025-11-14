# frozen_string_literal: true

require "graphql"

RSpec.describe "GraphQL Type Matchers" do
  # Define test GraphQL types with unique names
  class TypeMatcherPost < GraphQL::Schema::Object
    graphql_name "TypeMatcherPost"

    field :id, ID, null: false
    field :title, String, null: false
    field :body, String, null: true
  end

  class TypeMatcherUser < GraphQL::Schema::Object
    graphql_name "TypeMatcherUser"

    field :id, ID, null: false
    field :name, String, null: false
    field :email, String, null: true
    field :posts, [TypeMatcherPost], null: false do
      argument :limit, Integer, required: false
      argument :offset, Integer, required: false
      argument :status, String, required: true
    end
  end

  class TypeMatcherStatus < GraphQL::Schema::Enum
    graphql_name "TypeMatcherStatus"

    value "ACTIVE", "Active status"
    value "INACTIVE", "Inactive status"
    value "PENDING", "Pending status"
  end

  class TypeMatcherCreateUserInput < GraphQL::Schema::InputObject
    graphql_name "TypeMatcherCreateUserInput"

    argument :name, String, required: true
    argument :email, String, required: true
  end

  class TypeMatcherQuery < GraphQL::Schema::Object
    graphql_name "TypeMatcherQuery"

    field :user, TypeMatcherUser, null: false do
      argument :id, ID, required: true
    end

    field :users, [TypeMatcherUser], null: false do
      argument :limit, Integer, required: false
    end
  end

  class TypeMatcherMutation < GraphQL::Schema::Object
    graphql_name "TypeMatcherMutation"

    field :createUser, TypeMatcherUser, null: false do
      argument :input, TypeMatcherCreateUserInput, required: true
    end

    field :deleteUser, Boolean, null: false do
      argument :id, ID, required: true
    end
  end

  class TypeMatcherSchema < GraphQL::Schema
    query TypeMatcherQuery
    mutation TypeMatcherMutation
  end

  describe "have_field matcher" do
    it "matches when type has field" do
      expect(TypeMatcherUser).to have_field(:id)
      expect(TypeMatcherUser).to have_field(:name)
      expect(TypeMatcherUser).to have_field(:email)
    end

    it "matches field with correct type" do
      expect(TypeMatcherUser).to have_field(:id).of_type("ID!")
      expect(TypeMatcherUser).to have_field(:name).of_type("String!")
      expect(TypeMatcherUser).to have_field(:email).of_type("String")
    end

    it "matches field with array type" do
      expect(TypeMatcherUser).to have_field(:posts).of_type("[TypeMatcherPost!]!")
    end

    it "matches field with arguments" do
      expect(TypeMatcherUser).to have_field(:posts)
        .with_argument(:limit, "Int")
        .with_argument(:offset, "Int")
        .with_argument(:status, "String!")
    end

    it "fails when type does not have field" do
      expect(TypeMatcherUser).not_to have_field(:nonexistent)
    end

    it "fails when field has wrong type" do
      expect(TypeMatcherUser).not_to have_field(:id).of_type("String")
    end
  end

  describe "have_enum_values matcher" do
    it "matches when enum has all values" do
      expect(TypeMatcherStatus).to have_enum_values("ACTIVE", "INACTIVE", "PENDING")
    end

    it "matches when enum has subset of values" do
      expect(TypeMatcherStatus).to have_enum_values("ACTIVE", "INACTIVE")
    end

    it "fails when enum is missing values" do
      expect(TypeMatcherStatus).not_to have_enum_values("ACTIVE", "NONEXISTENT")
    end
  end

  describe "have_argument matcher" do
    let(:posts_field) { TypeMatcherUser.fields["posts"] }

    it "matches when field has argument" do
      expect(posts_field).to have_argument(:limit)
      expect(posts_field).to have_argument(:offset)
      expect(posts_field).to have_argument(:status)
    end

    it "matches argument with correct type" do
      expect(posts_field).to have_argument(:limit).of_type("Int")
      expect(posts_field).to have_argument(:offset).of_type("Int")
      expect(posts_field).to have_argument(:status).of_type("String!")
    end

    it "fails when field does not have argument" do
      expect(posts_field).not_to have_argument(:nonexistent)
    end

    it "fails when argument has wrong type" do
      expect(posts_field).not_to have_argument(:limit).of_type("String")
    end
  end

  describe "have_query matcher" do
    it "matches when schema has query" do
      expect(TypeMatcherSchema).to have_query(:user)
      expect(TypeMatcherSchema).to have_query(:users)
    end

    it "matches query with correct type" do
      expect(TypeMatcherSchema).to have_query(:user).of_type("TypeMatcherUser!")
      expect(TypeMatcherSchema).to have_query(:users).of_type("[TypeMatcherUser!]!")
    end

    it "matches query with arguments" do
      expect(TypeMatcherSchema).to have_query(:user).with_argument(:id, "ID!")
      expect(TypeMatcherSchema).to have_query(:users).with_argument(:limit, "Int")
    end

    it "fails when schema does not have query" do
      expect(TypeMatcherSchema).not_to have_query(:nonexistent)
    end
  end

  describe "have_mutation matcher" do
    it "matches when schema has mutation" do
      expect(TypeMatcherSchema).to have_mutation(:createUser)
      expect(TypeMatcherSchema).to have_mutation(:deleteUser)
    end

    it "matches mutation with correct type" do
      expect(TypeMatcherSchema).to have_mutation(:createUser).of_type("TypeMatcherUser!")
      expect(TypeMatcherSchema).to have_mutation(:deleteUser).of_type("Boolean!")
    end

    it "matches mutation with arguments" do
      expect(TypeMatcherSchema).to have_mutation(:createUser)
        .with_argument(:input, "TypeMatcherCreateUserInput!")
      expect(TypeMatcherSchema).to have_mutation(:deleteUser)
        .with_argument(:id, "ID!")
    end

    it "fails when schema does not have mutation" do
      expect(TypeMatcherSchema).not_to have_mutation(:nonexistent)
    end
  end
end
