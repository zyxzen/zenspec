# frozen_string_literal: true

require "rspec/core/formatters/base_formatter"

module Zenspec
  module Formatters
    # RSpec formatter that displays test progress using Docker-style progress bar
    #
    # @example Usage
    #   # In your .rspec file or command line:
    #   --require zenspec/formatters/progress_formatter
    #   --format Zenspec::Formatters::ProgressFormatter
    #
    # @example Command line
    #   rspec --require zenspec/formatters/progress_formatter \
    #         --format Zenspec::Formatters::ProgressFormatter
    #
    class ProgressFormatter < RSpec::Core::Formatters::BaseFormatter
      RSpec::Core::Formatters.register self,
                                       :start,
                                       :example_started,
                                       :example_passed,
                                       :example_failed,
                                       :example_pending,
                                       :dump_summary,
                                       :dump_failures

      def initialize(output)
        super
        @loader = nil
        @failed_examples = []
        @pending_examples = []
      end

      # Called at the start of the test suite
      def start(notification)
        @total_count = notification.count
        @loader = ProgressLoader.new(
          total: @total_count,
          description: "Running examples",
          output: output
        )
      end

      # Called when an example starts
      def example_started(_notification)
        # Can add custom logic here if needed
      end

      # Called when an example passes
      def example_passed(notification)
        @loader.increment(description: build_description(notification.example, "✓"))
      end

      # Called when an example fails
      def example_failed(notification)
        @failed_examples << notification.example
        @loader.increment(description: build_description(notification.example, "✗"))
      end

      # Called when an example is pending
      def example_pending(notification)
        @pending_examples << notification.example
        @loader.increment(description: build_description(notification.example, "*"))
      end

      # Called at the end to print summary
      def dump_summary(summary)
        @loader.finish(description: "Completed")

        output.puts
        output.puts summary_line(summary)

        return unless @pending_examples.any?

        output.puts
        output.puts "Pending examples:"
        @pending_examples.each do |example|
          output.puts "  #{example.full_description}"
        end
      end

      # Called to print failure details
      def dump_failures(notification)
        return if notification.failed_examples.empty?

        output.puts
        output.puts "Failures:"
        output.puts

        notification.failed_examples.each_with_index do |example, index|
          output.puts "  #{index + 1}) #{example.full_description}"
          output.puts "     #{failure_message(example)}"
          output.puts "     # #{format_location(example)}"
          output.puts
        end
      end

      private

      # Build description for current example
      def build_description(example, status_symbol)
        file_path = example.metadata[:file_path].split("/").last(2).join("/")
        "#{status_symbol} #{file_path}:#{example.metadata[:line_number]}"
      end

      # Build summary line
      def summary_line(summary)
        parts = []
        parts << "#{summary.example_count} examples"
        parts << "#{summary.failure_count} failures" if summary.failure_count.positive?
        parts << "#{summary.pending_count} pending" if summary.pending_count.positive?

        duration = "Finished in #{format_duration(summary.duration)}"
        "#{parts.join(', ')} (#{duration})"
      end

      # Format duration
      def format_duration(seconds)
        if seconds < 1
          "#{(seconds * 1000).round} milliseconds"
        elsif seconds < 60
          "#{seconds.round(2)} seconds"
        else
          minutes = (seconds / 60).floor
          remaining_seconds = (seconds % 60).round
          "#{minutes} minutes #{remaining_seconds} seconds"
        end
      end

      # Get failure message from example
      def failure_message(example)
        exception = example.execution_result.exception
        return "No exception message" unless exception

        message = exception.message.split("\n").first
        message.length > 100 ? "#{message[0..97]}..." : message
      end

      # Format file location
      def format_location(example)
        "./#{example.metadata[:file_path]}:#{example.metadata[:line_number]}"
      end
    end
  end
end
