# Zenspec

A comprehensive RSpec matcher library for testing GraphQL APIs, Interactor service objects, and Rails applications. Includes Shoulda Matchers integration for clean, expressive tests.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "zenspec"
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install zenspec
```

## Features

- **GraphQL Matchers** - Test GraphQL queries, mutations, types, and schemas
- **Interactor Matchers** - Test service objects with clean syntax
- **GraphQL Helpers** - Execute queries and mutations with ease
- **Shoulda Matchers** - Automatically configured for Rails models and controllers
- **Rails Integration** - Automatically loads in Rails applications
- **Non-Rails Support** - Works in any Ruby project

## Usage

```ruby
# In your spec/rails_helper.rb or spec/spec_helper.rb
require "zenspec"

# Everything is automatically configured!
```

---

## Interactor Matchers

### Basic Usage

```ruby
RSpec.describe CreateUser do
  subject(:result) { described_class.call(params) }

  context "with valid params" do
    let(:params) { { name: "John", email: "john@example.com" } }

    # Shoulda-style one-liners
    it { is_expected.to succeed }
    it { is_expected.to set_context(:user) }
    it { is_expected.to succeed.with_data(kind_of(User)) }
  end

  context "with invalid params" do
    let(:params) { { name: "", email: "invalid" } }

    it { is_expected.to fail_interactor }
    it { is_expected.to fail_interactor.with_error("validation_failed") }
    it { is_expected.to have_error_code("validation_failed") }
  end
end
```

### Available Matchers

#### `succeed`

```ruby
expect(result).to succeed
expect(result).to succeed.with_data("expected value")
expect(result).to succeed.with_context(:user_id, 123)
expect(CreateUser).to succeed  # Works with classes too
```

#### `fail_interactor`

```ruby
expect(result).to fail_interactor
expect(result).to fail_interactor.with_error("invalid_input")
expect(result).to fail_interactor.with_errors("error1", "error2")
```

#### `have_error_code` / `have_error_codes`

```ruby
expect(result).to have_error_code("not_found")
expect(result).to have_error_codes("error1", "error2")
```

#### `set_context`

```ruby
expect(result).to set_context(:user)
expect(result).to set_context(:user_id, 123)
expect(result).to set_context(:data).to(expected_value)
```

---

## GraphQL Response Matchers

### Basic Usage

```ruby
RSpec.describe "User Queries" do
  subject(:result) { graphql_execute_as(user, query, variables: { id: user.id }) }

  let(:query) do
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

  # Shoulda-style
  it { is_expected.to succeed_graphql }
  it { is_expected.to have_graphql_data("user") }
  it { is_expected.to have_graphql_data("user", "name").with_value("John") }
end
```

### Available Matchers

#### `have_graphql_data`

```ruby
# Basic checks
expect(result).to have_graphql_data
expect(result).to have_graphql_data("user")
expect(result).to have_graphql_data("user", "id")

# With specific value
expect(result).to have_graphql_data("user", "name").with_value("John Doe")

# Partial matching (subset)
expect(result).to have_graphql_data("user").matching(
  id: "123",
  name: "John"
  # other fields can exist but aren't checked
)

# Inclusion (contains these values)
expect(result).to have_graphql_data("user").that_includes(name: "John")

# Presence checks
expect(result).to have_graphql_data("users").that_is_present
expect(result).to have_graphql_data("deletedAt").that_is_null

# Array count
expect(result).to have_graphql_data("users").with_count(5)
```

#### `have_graphql_errors`

```ruby
# Basic error check
expect(result).to have_graphql_errors

# With specific message
expect(result).to have_graphql_error.with_message("Not found")

# With extensions
expect(result).to have_graphql_error.with_extensions(code: "NOT_FOUND")

# At specific path
expect(result).to have_graphql_error.at_path(["user", "email"])
```

#### `succeed_graphql`

```ruby
expect(result).to succeed_graphql
```

#### `have_graphql_field` / `have_graphql_fields`

```ruby
data = result.dig("data", "user")

expect(data).to have_graphql_field("name")
expect(data).to have_graphql_field(:email)

expect(data).to have_graphql_fields(
  id: "123",
  name: "John Doe",
  email: "john@example.com"
)
```

---

## GraphQL Type Matchers

Test your GraphQL schema types, queries, and mutations.

### Type Field Testing

```ruby
RSpec.describe UserType do
  subject { described_class }

  # Shoulda-style
  it { is_expected.to have_field(:id).of_type("ID!") }
  it { is_expected.to have_field(:name).of_type("String!") }
  it { is_expected.to have_field(:email).of_type("String") }
  it { is_expected.to have_field(:posts).of_type("[Post!]!") }

  # With arguments
  it do
    is_expected.to have_field(:posts)
      .with_argument(:limit, "Int")
      .with_argument(:offset, "Int")
  end
end
```

### Enum Testing

```ruby
RSpec.describe StatusEnum do
  subject { described_class }

  it { is_expected.to have_enum_values("ACTIVE", "INACTIVE", "PENDING") }
end
```

### Schema Query/Mutation Testing

```ruby
RSpec.describe AppSchema do
  subject { described_class }

  # Query fields
  it { is_expected.to have_query(:user).with_argument(:id, "ID!") }
  it { is_expected.to have_query(:users).of_type("[User!]!") }

  # Mutation fields
  it { is_expected.to have_mutation(:createUser).with_argument(:input, "CreateUserInput!") }
  it { is_expected.to have_mutation(:deleteUser).of_type("Boolean!") }
end
```

### Field Argument Testing

```ruby
RSpec.describe "UserType posts field" do
  subject(:field) { UserType.fields["posts"] }

  it { is_expected.to have_argument(:limit).of_type("Int") }
  it { is_expected.to have_argument(:status).of_type("Status!") }
end
```

---

## GraphQL Execution Helpers

Execute GraphQL queries and mutations with ease.

### `graphql_execute`

```ruby
# Basic execution
result = graphql_execute(query, variables: { id: "123" }, context: { current_user: user })

# With custom schema
result = graphql_execute(query, schema: MySchema)
```

### `graphql_execute_as`

```ruby
# Automatically adds user to context
result = graphql_execute_as(user, query, variables: { id: "123" })

# Custom context key
result = graphql_execute_as(user, query, context_key: :admin)
```

### `graphql_mutate`

```ruby
# Execute mutations
result = graphql_mutate(mutation, input: { name: "John" }, context: { current_user: user })
```

### `graphql_mutate_as`

```ruby
# Execute mutation as user
result = graphql_mutate_as(user, mutation, input: { name: "John" })
```

---

## Shoulda Matchers

Automatically includes and configures [Shoulda Matchers](https://github.com/thoughtbot/shoulda-matchers) for Rails projects.

### Model Validations

```ruby
RSpec.describe User do
  subject { build(:user) }

  # Validations
  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  it { is_expected.to validate_length_of(:password).is_at_least(8) }

  # Associations
  it { is_expected.to have_many(:posts).dependent(:destroy) }
  it { is_expected.to belong_to(:organization) }

  # Database columns
  it { is_expected.to have_db_column(:email).of_type(:string) }
  it { is_expected.to have_db_index(:email).unique }
end
```

### Controller Testing

```ruby
RSpec.describe UsersController do
  describe "GET #index" do
    it { is_expected.to respond_with(:success) }
    it { is_expected.to render_template(:index) }
  end

  describe "POST #create" do
    it { is_expected.to permit(:name, :email).for(:create) }
  end
end
```

---

## Complete Examples

### Full Interactor Test Suite

```ruby
RSpec.describe CreateUser do
  subject(:result) { described_class.call(params) }

  describe "success cases" do
    let(:params) { { name: "John Doe", email: "john@example.com" } }

    it { is_expected.to succeed }
    it { is_expected.to set_context(:user) }
    it { is_expected.to succeed.with_context(:user, kind_of(User)) }

    it "creates a user with correct attributes" do
      expect(result).to succeed
      expect(result.user.name).to eq("John Doe")
      expect(result.user.email).to eq("john@example.com")
    end
  end

  describe "failure cases" do
    context "with blank name" do
      let(:params) { { name: "", email: "john@example.com" } }

      it { is_expected.to fail_interactor }
      it { is_expected.to fail_interactor.with_error("blank_name") }
      it { is_expected.to have_error_code("blank_name") }
    end

    context "with duplicate email" do
      before { create(:user, email: "john@example.com") }

      let(:params) { { name: "John", email: "john@example.com" } }

      it { is_expected.to fail_interactor.with_error("duplicate_email") }
    end
  end
end
```

### Full GraphQL Test Suite

```ruby
RSpec.describe "User Queries" do
  let(:user) { create(:user, name: "John Doe", email: "john@example.com") }

  describe "user query" do
    subject(:result) { graphql_execute_as(user, query, variables: { id: user.id }) }

    let(:query) do
      <<~GQL
        query GetUser($id: ID!) {
          user(id: $id) {
            id
            name
            email
            posts {
              id
              title
            }
          }
        }
      GQL
    end

    it { is_expected.to succeed_graphql }
    it { is_expected.to have_graphql_data("user") }

    it "returns correct user data" do
      expect(result).to have_graphql_data("user").matching(
        id: user.id,
        name: "John Doe",
        email: "john@example.com"
      )
    end

    it { is_expected.to have_graphql_data("user", "posts").that_is_present }

    context "when user has posts" do
      before { create_list(:post, 3, user: user) }

      it { is_expected.to have_graphql_data("user", "posts").with_count(3) }
    end

    context "when not authenticated" do
      subject(:result) { graphql_execute(query, variables: { id: user.id }) }

      it { is_expected.to have_graphql_error.with_message("Authentication required") }
      it { is_expected.to have_graphql_error.with_extensions(code: "UNAUTHENTICATED") }
    end
  end
end
```

### Full GraphQL Type Test Suite

```ruby
RSpec.describe Types::UserType do
  subject { described_class }

  # Basic fields
  it { is_expected.to have_field(:id).of_type("ID!") }
  it { is_expected.to have_field(:name).of_type("String!") }
  it { is_expected.to have_field(:email).of_type("String") }
  it { is_expected.to have_field(:createdAt).of_type("ISO8601DateTime!") }

  # Associations
  it { is_expected.to have_field(:posts).of_type("[Post!]!") }
  it { is_expected.to have_field(:organization).of_type("Organization") }

  # Fields with arguments
  describe "posts field" do
    subject(:field) { described_class.fields["posts"] }

    it { is_expected.to have_argument(:limit).of_type("Int") }
    it { is_expected.to have_argument(:offset).of_type("Int") }
    it { is_expected.to have_argument(:status).of_type("PostStatus") }
  end
end

RSpec.describe Types::PostStatusEnum do
  subject { described_class }

  it { is_expected.to have_enum_values("DRAFT", "PUBLISHED", "ARCHIVED") }
end

RSpec.describe AppSchema do
  subject { described_class }

  describe "queries" do
    it { is_expected.to have_query(:user).with_argument(:id, "ID!") }
    it { is_expected.to have_query(:users).of_type("[User!]!") }
    it { is_expected.to have_query(:currentUser).of_type("User") }
  end

  describe "mutations" do
    it { is_expected.to have_mutation(:createUser).with_argument(:input, "CreateUserInput!") }
    it { is_expected.to have_mutation(:updateUser).with_argument(:input, "UpdateUserInput!") }
    it { is_expected.to have_mutation(:deleteUser).of_type("Boolean!") }
  end
end
```

---

## Configuration

Zenspec works out of the box with sensible defaults. For Rails applications, it automatically configures itself through a Railtie.

### Manual Configuration (Non-Rails)

If you're not using Rails, the matchers are still automatically included when you require zenspec:

```ruby
# spec/spec_helper.rb
require "zenspec"

# That's it! All matchers and helpers are available
```

---

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/zyxzen/zenspec. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/zyxzen/zenspec/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Zenspec project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/zyxzen/zenspec/blob/main/CODE_OF_CONDUCT.md).
