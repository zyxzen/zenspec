# Zenspec

A comprehensive RSpec matcher library for testing GraphQL APIs, Interactor service objects, and Rails applications.

**Features:**
- GraphQL schema type matchers with snake_case support
- GraphQL response matchers for queries and mutations
- Interactor/service object matchers
- Shoulda matchers integration
- Beautiful progress bar formatter

---

## 30-Second Quickstart

```ruby
# 1. Add to Gemfile
gem "zenspec"

# 2. Bundle install
bundle install

# 3. Start testing!
RSpec.describe UserType do
  # Test GraphQL types (supports snake_case!)
  it { is_expected.to have_field(:id).of_type("ID!") }
  it { is_expected.to have_field(:current_user).of_type("User") }
end

RSpec.describe "GraphQL Queries" do
  subject(:result) { graphql_execute(query) }

  let(:query) do
    <<~GQL
      query { user(id: "123") { id name } }
    GQL
  end

  # Test responses
  it { is_expected.to succeed_graphql }
  it { is_expected.to have_graphql_data("user", "name").with_value("John") }
end

RSpec.describe CreateUser do
  subject(:result) { described_class.call(name: "John") }

  # Test interactors
  it { is_expected.to succeed }
  it { is_expected.to set_context(:user) }
end
```

---

## Complete Matchers Reference

### GraphQL Type Matchers

Test your GraphQL schema types, fields, and structure.

| Matcher | Usage | Description |
|---------|-------|-------------|
| `have_field(name)` | `have_field(:user)` | Check if type has a field (snake_case supported) |
| `.of_type(type)` | `.of_type("User!")` | Verify field return type |
| `.with_argument(name, type)` | `.with_argument(:id, "ID!")` | Check field has argument (snake_case supported) |
| `have_argument(name)` | `have_argument(:limit)` | Check argument exists on field |
| `.of_type(type)` | `.of_type("Int")` | Verify argument type |
| `have_enum_values(*values)` | `have_enum_values("ACTIVE", "PENDING")` | Verify enum contains values |
| `have_query(name)` | `have_query(:current_user)` | Check schema has query (snake_case supported) |
| `have_mutation(name)` | `have_mutation(:create_user)` | Check schema has mutation (snake_case supported) |

**Examples:**

```ruby
# Field testing (snake_case supported!)
expect(UserType).to have_field(:id).of_type("ID!")
expect(UserType).to have_field(:current_user).of_type("User")  # Works with snake_case!
expect(UserType).to have_field(:posts).of_type("[Post!]!")

# Fields with arguments (snake_case supported!)
expect(UserType).to have_field(:posts)
  .with_argument(:limit, "Int")
  .with_argument(:include_archived, "Boolean")  # snake_case works!

# Enum testing
expect(StatusEnum).to have_enum_values("ACTIVE", "INACTIVE", "PENDING")

# Schema queries (snake_case supported!)
expect(AppSchema).to have_query(:user).with_argument(:id, "ID!")
expect(AppSchema).to have_query(:current_user).of_type("User")  # snake_case!

# Schema mutations (snake_case supported!)
expect(AppSchema).to have_mutation(:create_user).of_type("UserPayload!")
expect(AppSchema).to have_mutation(:update_user_status)
  .with_argument(:user_id, "ID!")           # snake_case arguments!
  .with_argument(:new_status, "Status!")
```

### GraphQL Response Matchers

Test GraphQL query and mutation responses.

| Matcher | Usage | Description |
|---------|-------|-------------|
| `succeed_graphql` | `expect(result).to succeed_graphql` | Verify query/mutation succeeded (no errors) |
| `have_graphql_data(path...)` | `have_graphql_data("user", "name")` | Check response data at path |
| `.with_value(expected)` | `.with_value("John")` | Exact value match |
| `.matching(hash)` | `.matching(id: "123", name: "John")` | Partial hash match |
| `.that_includes(hash)` | `.that_includes(name: "John")` | Includes these key-value pairs |
| `.that_is_present` | `.that_is_present` | Value exists and not null |
| `.that_is_null` | `.that_is_null` | Value is explicitly null |
| `.with_count(n)` | `.with_count(5)` | Array has exactly n items |
| `have_graphql_error` | `have_graphql_error` | Has at least one error |
| `.with_message(msg)` | `.with_message("Not found")` | Error message matches |
| `.with_extensions(hash)` | `.with_extensions(code: "NOT_FOUND")` | Error extensions match |
| `.at_path(array)` | `.at_path(["user", "email"])` | Error occurred at path |
| `have_graphql_errors(n)` | `have_graphql_errors(2)` | Has exactly n errors |
| `have_graphql_field(name)` | `have_graphql_field("user")` | Response has field |
| `have_graphql_fields(hash)` | `have_graphql_fields("user" => true)` | Response has multiple fields |

**Examples:**

```ruby
# Basic success check
expect(result).to succeed_graphql

# Data checks
expect(result).to have_graphql_data("user")
expect(result).to have_graphql_data("user", "name").with_value("John")
expect(result).to have_graphql_data("user", "email").that_is_present

# Hash matching
expect(result).to have_graphql_data("user").matching(
  id: "123",
  name: "John Doe",
  email: "john@example.com"
)

# Array checks
expect(result).to have_graphql_data("users").with_count(5)
expect(result).to have_graphql_data("users").that_is_present

# Error handling
expect(result).to have_graphql_error
expect(result).to have_graphql_error.with_message("Not found")
expect(result).to have_graphql_error.with_extensions(code: "NOT_FOUND")
expect(result).to have_graphql_error.at_path(["user", "email"])
expect(result).to have_graphql_errors(2)
```

### Interactor Matchers

Test your Interactor service objects.

| Matcher | Usage | Description |
|---------|-------|-------------|
| `succeed` | `expect(result).to succeed` | Interactor succeeded |
| `.with_context(key, value)` | `.with_context(:user, user)` | Check context value |
| `.with_data(value)` | `.with_data(user)` | Check context.data value |
| `fail_interactor` | `expect(result).to fail_interactor` | Interactor failed |
| `.with_error(code)` | `.with_error("not_found")` | Failed with specific error code |
| `.with_errors(*codes)` | `.with_errors("invalid", "missing")` | Failed with multiple error codes |
| `set_context(key)` | `set_context(:user)` | Context key was set |
| `set_context(key, value)` | `set_context(:user, user)` | Context key set to value |
| `have_error_code(code)` | `have_error_code("not_found")` | Has specific error code |
| `have_error_codes(*codes)` | `have_error_codes("a", "b")` | Has multiple error codes |

**Examples:**

```ruby
# Success checks
expect(result).to succeed
expect(result).to succeed.with_context(:user, kind_of(User))
expect(result).to succeed.with_data(user)
expect(result).to set_context(:user)

# Failure checks
expect(result).to fail_interactor
expect(result).to fail_interactor.with_error("validation_failed")
expect(result).to fail_interactor.with_errors("invalid_email", "missing_name")
expect(result).to have_error_code("not_found")
expect(result).to have_error_codes("invalid", "missing")
```

### GraphQL Helpers

Helper methods for executing GraphQL queries and mutations in tests.

| Helper | Usage | Description |
|--------|-------|-------------|
| `graphql_execute(query, **options)` | `graphql_execute(query, variables: {id: "123"})` | Execute GraphQL query |
| `graphql_execute_as(user, query, **options)` | `graphql_execute_as(user, query)` | Execute query with user in context |
| `graphql_mutate(mutation, **options)` | `graphql_mutate(mutation, input: {name: "John"})` | Execute GraphQL mutation |
| `graphql_mutate_as(user, mutation, **options)` | `graphql_mutate_as(user, mutation, input: {})` | Execute mutation with user in context |

**Examples:**

```ruby
# Execute query
result = graphql_execute(query, variables: { id: "123" }, context: { current_user: user })

# Execute as user (adds to context automatically)
result = graphql_execute_as(user, query, variables: { id: "123" })

# Execute mutation
result = graphql_mutate(mutation, input: { name: "John" }, context: { current_user: user })

# Execute mutation as user
result = graphql_mutate_as(user, mutation, input: { name: "John" })
```

---

## Detailed Usage Examples

### Testing GraphQL Types

```ruby
RSpec.describe UserType do
  subject { described_class }

  # Basic fields (snake_case supported!)
  it { is_expected.to have_field(:id).of_type("ID!") }
  it { is_expected.to have_field(:name).of_type("String!") }
  it { is_expected.to have_field(:email).of_type("String") }
  it { is_expected.to have_field(:current_user).of_type("User") }  # snake_case!

  # Array types
  it { is_expected.to have_field(:posts).of_type("[Post!]!") }

  # Fields with arguments (snake_case supported!)
  it do
    is_expected.to have_field(:posts)
      .with_argument(:limit, "Int")
      .with_argument(:offset, "Int")
      .with_argument(:include_archived, "Boolean")  # snake_case works!
  end
end

RSpec.describe StatusEnum do
  subject { described_class }

  it { is_expected.to have_enum_values("ACTIVE", "INACTIVE", "PENDING") }
end

RSpec.describe AppSchema do
  subject { described_class }

  # Queries (snake_case supported!)
  it { is_expected.to have_query(:user).with_argument(:id, "ID!") }
  it { is_expected.to have_query(:current_user).of_type("User") }

  # Mutations (snake_case supported!)
  it { is_expected.to have_mutation(:create_user).of_type("UserPayload!") }
  it { is_expected.to have_mutation(:update_user_status)
    .with_argument(:user_id, "ID!")
    .with_argument(:new_status, "Status!") }
end
```

### Testing GraphQL Queries

```ruby
RSpec.describe "User Queries" do
  subject(:result) { graphql_execute_as(user, query, variables: { id: user.id }) }

  let(:user) { create(:user, name: "John Doe", email: "john@example.com") }
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

  # Basic checks
  it { is_expected.to succeed_graphql }
  it { is_expected.to have_graphql_data("user") }
  it { is_expected.to have_graphql_data("user", "id").with_value(user.id) }
  it { is_expected.to have_graphql_data("user", "name").with_value("John Doe") }
  it { is_expected.to have_graphql_data("user", "email").that_is_present }

  # Full object matching
  it "returns correct user data" do
    expect(result).to have_graphql_data("user").matching(
      id: user.id,
      name: "John Doe",
      email: "john@example.com"
    )
  end

  # Partial matching
  it "includes user name" do
    expect(result).to have_graphql_data("user").that_includes(name: "John Doe")
  end
end

RSpec.describe "User List Query" do
  subject(:result) { graphql_execute(query) }

  let!(:users) { create_list(:user, 5) }
  let(:query) do
    <<~GQL
      query { users { id name } }
    GQL
  end

  it { is_expected.to succeed_graphql }
  it { is_expected.to have_graphql_data("users").with_count(5) }
  it { is_expected.to have_graphql_data("users").that_is_present }
end
```

### Testing GraphQL Mutations

```ruby
RSpec.describe "Create User Mutation" do
  subject(:result) do
    graphql_mutate_as(admin, mutation, input: { name: "Jane", email: "jane@example.com" })
  end

  let(:admin) { create(:user, :admin) }
  let(:mutation) do
    <<~GQL
      mutation CreateUser($input: CreateUserInput!) {
        createUser(input: $input) {
          user { id name email }
          errors
        }
      }
    GQL
  end

  context "with valid input" do
    it { is_expected.to succeed_graphql }
    it { is_expected.to have_graphql_data("createUser", "user", "name").with_value("Jane") }
    it { is_expected.to have_graphql_data("createUser", "user", "email").with_value("jane@example.com") }
    it { is_expected.to have_graphql_data("createUser", "errors").that_is_null }

    it "creates a new user" do
      expect { result }.to change(User, :count).by(1)
    end
  end

  context "with invalid input" do
    subject(:result) do
      graphql_mutate_as(admin, mutation, input: { name: "", email: "invalid" })
    end

    it { is_expected.to have_graphql_data("createUser", "user").that_is_null }
    it { is_expected.to have_graphql_data("createUser", "errors").that_is_present }
  end
end
```

### Testing GraphQL Errors

```ruby
RSpec.describe "User Query with errors" do
  subject(:result) { graphql_execute(query, variables: { id: "999" }) }

  let(:query) do
    <<~GQL
      query GetUser($id: ID!) {
        user(id: $id) { id name }
      }
    GQL
  end

  it { is_expected.not_to succeed_graphql }
  it { is_expected.to have_graphql_error }
  it { is_expected.to have_graphql_error.with_message("User not found") }
  it { is_expected.to have_graphql_error.with_extensions(code: "NOT_FOUND") }
  it { is_expected.to have_graphql_error.at_path(["user"]) }

  context "with multiple errors" do
    it { is_expected.to have_graphql_errors(2) }
  end
end
```

### Testing Interactors

```ruby
RSpec.describe CreateUser do
  subject(:result) { described_class.call(params) }

  context "with valid params" do
    let(:params) { { name: "John Doe", email: "john@example.com" } }

    it { is_expected.to succeed }
    it { is_expected.to set_context(:user) }
    it { is_expected.to succeed.with_context(:user, kind_of(User)) }

    it "creates a user" do
      expect(result.user).to be_persisted
      expect(result.user.name).to eq("John Doe")
    end
  end

  context "with invalid params" do
    let(:params) { { name: "", email: "invalid" } }

    it { is_expected.to fail_interactor }
    it { is_expected.to fail_interactor.with_error("validation_failed") }
    it { is_expected.to have_error_code("validation_failed") }

    it "does not create a user" do
      expect { result }.not_to change(User, :count)
    end
  end

  context "with multiple errors" do
    let(:params) { { name: "", email: "" } }

    it { is_expected.to fail_interactor.with_errors("missing_name", "missing_email") }
    it { is_expected.to have_error_codes("missing_name", "missing_email") }
  end
end

RSpec.describe UpdateUser do
  subject(:result) { described_class.call(user: user, name: new_name) }

  let(:user) { create(:user, name: "Old Name") }
  let(:new_name) { "New Name" }

  it { is_expected.to succeed }
  it { is_expected.to succeed.with_context(:user, user) }
  it { is_expected.to succeed.with_data(user) }

  it "updates the user's name" do
    expect { result }.to change { user.reload.name }.from("Old Name").to("New Name")
  end
end
```

### Testing with Shoulda Matchers

Shoulda matchers are automatically included for Rails projects.

```ruby
RSpec.describe User do
  subject { build(:user) }

  # Validations
  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  it { is_expected.to validate_length_of(:name).is_at_least(2).is_at_most(100) }

  # Associations
  it { is_expected.to have_many(:posts).dependent(:destroy) }
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to have_one(:profile) }
end
```

---

## Installation

Add this line to your application's Gemfile:

```ruby
gem "zenspec"
```

And then execute:

```bash
bundle install
```

That's it! All matchers and helpers are automatically available in your RSpec tests.

### Optional: Progress Bar Formatter

For a cleaner test output with a progress bar, add to your `.rspec` file:

```
--require zenspec/formatters/progress_bar_formatter
--format ProgressBarFormatter
--color
--require spec_helper
```

Or use via command line:

```bash
rspec --require zenspec/formatters/progress_bar_formatter --format ProgressBarFormatter
```

**Example output:**

```
✔ user_spec.rb                                                [10% 15/152]
✔ post_spec.rb                                                [20% 30/152]
⠿ auth_spec.rb --> authenticates with OAuth                   [30% 45/152]
```

**Icons:**
- ✔ Green - Passed
- ✗ Red - Failed
- ⠿ Yellow - Running (shows current test description)
- ⊘ Cyan - Pending

---

## Configuration

Zenspec works out of the box with sensible defaults. For Rails applications, it automatically:
- Includes all matchers in RSpec
- Configures Shoulda Matchers
- Sets up GraphQL helpers with your `AppSchema`

### Non-Rails Projects

```ruby
# spec/spec_helper.rb
require "zenspec"

# All matchers and helpers are now available!
```

### Custom GraphQL Schema

If your schema is not named `AppSchema`, you can configure it:

```ruby
# spec/spec_helper.rb
RSpec.configure do |config|
  config.include Zenspec::Helpers::GraphQLHelpers

  # Override the schema
  config.before do
    stub_const("AppSchema", YourCustomSchema)
  end
end
```

---

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then run the tests:

```bash
bundle exec rspec
```

To install this gem onto your local machine:

```bash
bundle exec rake install
```

---

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/zyxzen/zenspec.

Please ensure:
1. All tests pass (`bundle exec rspec`)
2. Code follows the existing style
3. New features include tests and documentation

---

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
