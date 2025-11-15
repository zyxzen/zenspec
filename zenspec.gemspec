# frozen_string_literal: true

require_relative "lib/zenspec/version"

Gem::Specification.new do |spec|
  spec.name = "zenspec"
  spec.version = Zenspec::VERSION
  spec.authors = ["Wilson Anciro"]
  spec.email = ["konekred@gmail.com"]

  spec.summary = "RSpec matchers for GraphQL, Interactor, and other common testing patterns"
  spec.description = "A collection of RSpec matchers for testing GraphQL queries and Interactor service objects."
  spec.homepage = "https://github.com/zyxzen/zenspec"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/zyxzen/zenspec"
  spec.metadata["changelog_uri"] = "https://github.com/zyxzen/zenspec/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "graphql", "~> 1.12"
  spec.add_dependency "interactor", "~> 3.0"
  spec.add_dependency "rspec", "~> 3.0"
  spec.add_dependency "shoulda-matchers", "~> 6.0"
end
