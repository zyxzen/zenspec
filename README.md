# Zenspec

A comprehensive RSpec matcher library for testing GraphQL APIs, Interactor service objects, and Rails applications.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "zenspec"
```

And then execute:

```bash
bundle install
```

## Quick Start

### 1. Add to your spec helper

```ruby
# In your spec/rails_helper.rb or spec/spec_helper.rb
require "zenspec"

# Everything is automatically configured!
```

### 2. (Optional) Add progress bar formatter to `.rspec`

```
--require zenspec/formatters/progress_bar_formatter
--format ProgressBarFormatter
--color
--require spec_helper
```

That's it! You can now use all GraphQL and Interactor matchers in your tests.

---

## GraphQL Testing

### Response Matchers

Test GraphQL query and mutation responses with clean, expressive matchers.

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

  # Basic checks
  it { is_expected.to succeed_graphql }
  it { is_expected.to have_graphql_data("user") }
  it { is_expected.to have_graphql_data("user", "name").with_value("John") }

  # Matching data
  it "returns correct user data" do
    expect(result).to have_graphql_data("user").matching(
      id: user.id,
      name: "John Doe",
      email: "john@example.com"
    )
  end

  # Array checks
  it { is_expected.to have_graphql_data("users").with_count(5) }
  it { is_expected.to have_graphql_data("users").that_is_present }

  # Error handling
  expect(result).to have_graphql_error.with_message("Not found")
  expect(result).to have_graphql_error.with_extensions(code: "NOT_FOUND")
  expect(result).to have_graphql_error.at_path(["user", "email"])
end
```

**Available matchers:**
- `succeed_graphql` - Verify successful query/mutation
- `have_graphql_data(path...)` - Check response data
- `have_graphql_error` / `have_graphql_errors` - Verify errors
- `have_graphql_field(name)` / `have_graphql_fields(hash)` - Check field presence

**Data matchers:**
- `.with_value(expected)` - Exact value match
- `.matching(hash)` - Partial hash match
- `.that_includes(hash)` - Includes these values
- `.that_is_present` / `.that_is_null` - Presence checks
- `.with_count(n)` - Array size

### Type Matchers

Test your GraphQL schema types, fields, and arguments.

```ruby
RSpec.describe UserType do
  subject { described_class }

  # Field testing
  it { is_expected.to have_field(:id).of_type("ID!") }
  it { is_expected.to have_field(:name).of_type("String!") }
  it { is_expected.to have_field(:email).of_type("String") }
  it { is_expected.to have_field(:posts).of_type("[Post!]!") }

  # Fields with arguments
  it do
    is_expected.to have_field(:posts)
      .with_argument(:limit, "Int")
      .with_argument(:offset, "Int")
  end
end

# Enum testing
RSpec.describe StatusEnum do
  subject { described_class }

  it { is_expected.to have_enum_values("ACTIVE", "INACTIVE", "PENDING") }
end

# Schema queries and mutations
RSpec.describe AppSchema do
  subject { described_class }

  it { is_expected.to have_query(:user).with_argument(:id, "ID!") }
  it { is_expected.to have_mutation(:createUser).of_type("UserPayload!") }
end
```

**Available matchers:**
- `have_field(name)` - Check field exists
- `of_type(type)` - Verify field type
- `with_argument(name, type)` - Check field arguments
- `have_argument(name)` - Check argument on field
- `have_enum_values(*values)` - Verify enum values
- `have_query(name)` / `have_mutation(name)` - Schema-level checks

### GraphQL Helpers

Execute queries and mutations easily in your tests.

```ruby
# Execute query
result = graphql_execute(query, variables: { id: "123" }, context: { current_user: user })

# Execute as user (automatically adds to context)
result = graphql_execute_as(user, query, variables: { id: "123" })

# Execute mutation
result = graphql_mutate(mutation, input: { name: "John" }, context: { current_user: user })

# Execute mutation as user
result = graphql_mutate_as(user, mutation, input: { name: "John" })
```

---

## Interactor Testing

Test your Interactor service objects with clean, expressive matchers.

```ruby
RSpec.describe CreateUser do
  subject(:result) { described_class.call(params) }

  context "with valid params" do
    let(:params) { { name: "John", email: "john@example.com" } }

    # Basic checks
    it { is_expected.to succeed }
    it { is_expected.to set_context(:user) }
    it { is_expected.to succeed.with_context(:user, kind_of(User)) }
  end

  context "with invalid params" do
    let(:params) { { name: "", email: "invalid" } }

    it { is_expected.to fail_interactor }
    it { is_expected.to fail_interactor.with_error("validation_failed") }
    it { is_expected.to have_error_code("validation_failed") }
  end
end
```

**Available matchers:**
- `succeed` - Verify interactor succeeded
  - `.with_context(key, value)` - Check context value
  - `.with_data(value)` - Check context.data value
- `fail_interactor` - Verify interactor failed
  - `.with_error(code)` - Check single error code
  - `.with_errors(*codes)` - Check multiple error codes
- `set_context(key, value)` - Check context was set
- `have_error_code(code)` / `have_error_codes(*codes)` - Check error codes

---

## Shoulda Matchers

Automatically includes and configures [Shoulda Matchers](https://github.com/thoughtbot/shoulda-matchers) for Rails projects.

```ruby
RSpec.describe User do
  subject { build(:user) }

  # Validations
  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_uniqueness_of(:email).case_insensitive }

  # Associations
  it { is_expected.to have_many(:posts).dependent(:destroy) }
  it { is_expected.to belong_to(:organization) }
end
```

---

## Progress Bar Formatter

Clean, colorful test output with status icons.

### Setup

Add to your `.rspec` file:

```
--require zenspec/formatters/progress_bar_formatter
--format ProgressBarFormatter
```

Or use via command line:

```bash
rspec --require zenspec/formatters/progress_bar_formatter --format ProgressBarFormatter
```

### Output

```
✔ user_spec.rb                                                [10% 1/10]
✔ post_spec.rb                                                [20% 2/10]
⠿ auth_spec.rb --> authenticates with OAuth                   [30% 3/10]
```

**Icons:**
- ✔ Green - Passed
- ✗ Red - Failed
- ⠿ Yellow - Running (shows test description)
- ⊘ Cyan - Pending

---

## Configuration

Zenspec works out of the box with sensible defaults. For Rails applications, it automatically configures itself.

### Non-Rails Projects

```ruby
# spec/spec_helper.rb
require "zenspec"

# That's it! All matchers and helpers are available
```

---

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/zyxzen/zenspec.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
