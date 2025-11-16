## [Unreleased]

## [0.3.1] - 2025-11-16

### Fixed
- **Critical**: Fixed falsy value handling in `have_graphql_data` matcher - now correctly handles `false`, `0`, and empty string values
- **Critical**: Fixed falsy data value bug in interactor `succeed` matcher - now correctly handles `false` and `0` as expected data
- Improved snake_case to camelCase conversion to handle edge cases (leading/trailing underscores, consecutive underscores)

### Changed
- Extracted duplicated type conversion methods to shared `FieldNameHelper` module (reduces code duplication by ~120 lines)
- Pre-compiled ANSI regex in `ProgressBarFormatter` for better performance
- Made global `ProgressBarFormatter` constant conditional to prevent namespace conflicts
- Added documentation comments to magic numbers explaining their values

### Added
- Support for error count validation in `have_graphql_errors` matcher: `expect(result).to have_graphql_errors(2)`
- CI testing for Ruby 3.2, 3.3, and 3.4 (expanded from single version)

## [0.2.0] - 2025-11-16

### Changed
- Updated graphql dependency from ~> 1.12 to ~> 2.5
- **Breaking**: Requires GraphQL 2.5 or higher

## [0.1.0] - 2025-11-15

- Initial release
