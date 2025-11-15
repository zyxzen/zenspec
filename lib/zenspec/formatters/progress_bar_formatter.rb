# frozen_string_literal: true

require "rspec/core/formatters/base_formatter"
require "io/console"

module Zenspec
  module Formatters
    # Custom RSpec formatter that displays test execution with spinning animation,
    # one line per file, and right-aligned progress.
    #
    # @example Usage in .rspec file
    #   --require zenspec/formatters/progress_bar_formatter
    #   --format Zenspec::Formatters::ProgressBarFormatter
    #
    # @example Command line usage
    #   rspec --require zenspec/formatters/progress_bar_formatter \
    #         --format Zenspec::Formatters::ProgressBarFormatter
    #
    # Format while running: [spinner] filename --> test description [percentage current/total]
    # Format when done: [icon] filename [percentage current/total]
    #
    # Icons:
    #   ✔ - All tests passed (green)
    #   ✗ - Any test failed (red)
    #   ⊘ - Pending tests (cyan)
    #   Spinner - Running (yellow): ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏
    #
    class ProgressBarFormatter < RSpec::Core::Formatters::BaseFormatter
      RSpec::Core::Formatters.register self,
                                       :start,
                                       :example_started,
                                       :example_passed,
                                       :example_failed,
                                       :example_pending,
                                       :dump_summary,
                                       :dump_failures

      # ANSI color codes
      COLORS = {
        green: "\e[32m",
        red: "\e[31m",
        yellow: "\e[33m",
        cyan: "\e[36m",
        white: "\e[37m",
        bright_white: "\e[97m",
        reset: "\e[0m"
      }.freeze

      # Status icons
      ICONS = {
        passed: "✔",
        failed: "✗",
        pending: "⊘"
      }.freeze

      # Spinner frames for animation
      SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"].freeze

      # Spinner update interval in seconds
      SPINNER_INTERVAL = 0.08

      # Default terminal width if unable to detect
      DEFAULT_TERMINAL_WIDTH = 120

      # Minimum padding between left and right parts
      MIN_PADDING = 2

      def initialize(output)
        super
        @current_count = 0
        @total_count = 0
        @failed_examples = []
        @pending_examples = []

        # File tracking
        @file_states = {} # filename -> {passed: 0, failed: 0, pending: 0, current_test: nil}
        @current_file = nil
        @completed_files = [] # Track files that are done

        # Spinner state
        @spinner_frame = 0
        @spinner_thread = nil
        @mutex = Mutex.new
        @spinner_running = false
      end

      # Called at the start of the test suite
      def start(notification)
        @total_count = notification.count
        output.puts
      end

      # Called when an example starts
      def example_started(notification)
        @mutex.synchronize do
          @current_count += 1
          filename = extract_filename(notification.example)

          # Check if we moved to a new file
          if @current_file && @current_file != filename
            # Finalize the previous file
            finalize_file(@current_file)
          end

          # Initialize file state if needed
          @file_states[filename] ||= { passed: 0, failed: 0, pending: 0, current_test: nil }
          @file_states[filename][:current_test] = notification.example.description
          @current_file = filename

          # Start spinner if not already running
          start_spinner unless @spinner_running
        end
      end

      # Called when an example passes
      def example_passed(notification)
        @mutex.synchronize do
          filename = extract_filename(notification.example)
          @file_states[filename][:passed] += 1
          @file_states[filename][:current_test] = nil
        end
      end

      # Called when an example fails
      def example_failed(notification)
        @mutex.synchronize do
          filename = extract_filename(notification.example)
          @file_states[filename][:failed] += 1
          @file_states[filename][:current_test] = nil
          @failed_examples << notification.example
        end
      end

      # Called when an example is pending
      def example_pending(notification)
        @mutex.synchronize do
          filename = extract_filename(notification.example)
          @file_states[filename][:pending] += 1
          @file_states[filename][:current_test] = nil
          @pending_examples << notification.example
        end
      end

      # Called at the end to print summary
      def dump_summary(summary)
        @mutex.synchronize do
          # Finalize the last file
          finalize_file(@current_file) if @current_file

          # Stop spinner
          stop_spinner
        end

        output.puts
        output.puts
        output.puts colorize("=" * terminal_width, :bright_white)
        output.puts colorize("Test Summary", :bright_white)
        output.puts colorize("=" * terminal_width, :bright_white)
        output.puts

        # Summary statistics
        output.puts summary_line(summary)
        output.puts "Duration: #{format_duration(summary.duration)}"
        output.puts

        # Pending examples
        if @pending_examples.any?
          output.puts
          output.puts colorize("Pending Examples:", :cyan)
          @pending_examples.each do |example|
            output.puts colorize("  #{ICONS[:pending]} #{example.full_description}", :cyan)
            output.puts colorize("     # #{format_location(example)}", :cyan)
          end
        end
      end

      # Called to print failure details
      def dump_failures(notification)
        return if notification.failed_examples.empty?

        output.puts
        output.puts colorize("Failures:", :red)
        output.puts

        notification.failed_examples.each_with_index do |example, index|
          output.puts colorize("  #{index + 1}) #{example.full_description}", :red)

          exception = example.execution_result.exception
          if exception
            output.puts colorize("     #{exception.class}: #{exception.message}", :red)

            # Print backtrace (first 3 lines)
            if exception.backtrace
              exception.backtrace.first(3).each do |line|
                output.puts colorize("       #{line}", :red)
              end
            end
          end

          output.puts colorize("     # #{format_location(example)}", :red)
          output.puts
        end
      end

      private

      # Start the spinner thread
      def start_spinner
        return if @spinner_running

        @spinner_running = true
        @spinner_thread = Thread.new do
          loop do
            break unless @spinner_running

            @mutex.synchronize do
              update_current_file_line if @current_file && !@completed_files.include?(@current_file)
              @spinner_frame = (@spinner_frame + 1) % SPINNER_FRAMES.length
            end

            sleep SPINNER_INTERVAL
          end
        end
      end

      # Stop the spinner thread
      def stop_spinner
        @spinner_running = false
        @spinner_thread&.join
        @spinner_thread = nil
      end

      # Update the current file's line (called by spinner thread)
      def update_current_file_line
        return unless @current_file
        return if @completed_files.include?(@current_file)

        file_state = @file_states[@current_file]
        return unless file_state

        # Build the line for running state
        icon = SPINNER_FRAMES[@spinner_frame]
        color = :yellow
        filename = @current_file
        description = file_state[:current_test] || "running..."
        progress = format_progress

        # Format: [spinner] filename --> test description [progress]
        left_part = "#{icon} #{filename} --> #{description}"
        right_part = progress

        # Calculate padding
        width = terminal_width
        visual_length = strip_ansi(left_part).length + strip_ansi(right_part).length

        if visual_length + MIN_PADDING >= width
          # Truncate description to fit
          # Format: icon(1) + " "(1) + filename(n) + " --> "(5) = 7 + n total before description
          max_desc_length = width - icon.length - filename.length - 6 - right_part.length - MIN_PADDING
          max_desc_length = [max_desc_length, 10].max # Minimum 10 chars for description
          description = truncate_string(description, max_desc_length)
          left_part = "#{icon} #{filename} --> #{description}"
          visual_length = strip_ansi(left_part).length + strip_ansi(right_part).length
        end

        padding_length = [width - visual_length, MIN_PADDING].max

        # Build the full line with colors
        colored_left = "#{colorize(icon, color)} #{colorize(filename, color)} --> #{colorize(description, color)}"
        colored_right = colorize(right_part, :bright_white)

        full_line = "#{colored_left}#{' ' * padding_length}#{colored_right}"

        # Print without newline (updates in place)
        output.print "\r#{full_line}"
        output.flush
      end

      # Finalize a file (write final status line)
      def finalize_file(filename)
        return unless filename
        return if @completed_files.include?(filename)

        @completed_files << filename

        file_state = @file_states[filename]
        return unless file_state

        # Determine final status
        status = if file_state[:failed] > 0
                   :failed
                 elsif file_state[:pending] > 0
                   :pending
                 else
                   :passed
                 end

        icon = ICONS[status]
        color = status_color(status)
        progress = format_progress

        # Format: [icon] filename [progress]
        left_part = "#{icon} #{filename}"
        right_part = progress

        # Calculate padding
        width = terminal_width
        visual_length = strip_ansi(left_part).length + strip_ansi(right_part).length
        padding_length = [width - visual_length, MIN_PADDING].max

        # Build the full line with colors
        colored_left = "#{colorize(icon, color)} #{colorize(filename, color)}"
        colored_right = colorize(right_part, :bright_white)

        full_line = "#{colored_left}#{' ' * padding_length}#{colored_right}"

        # Clear the current line and print the final line with newline
        output.print "\r#{' ' * width}\r"
        output.puts full_line
      end

      # Get color for status
      def status_color(status)
        case status
        when :passed then :green
        when :failed then :red
        when :running then :yellow
        when :pending then :cyan
        else :white
        end
      end

      # Colorize text
      def colorize(text, color)
        return text unless color && COLORS[color]

        "#{COLORS[color]}#{text}#{COLORS[:reset]}"
      end

      # Strip ANSI color codes from text
      def strip_ansi(text)
        text.gsub(/\e\[[0-9;]*m/, "")
      end

      # Extract short filename from example
      def extract_filename(example)
        file_path = example.metadata[:file_path]
        return "unknown" unless file_path

        # Get just the filename (not the full path)
        File.basename(file_path)
      end

      # Format progress as [percentage current/total]
      def format_progress
        percentage = (@current_count.to_f / @total_count * 100).round
        "[#{percentage}% #{@current_count}/#{@total_count}]"
      end

      # Get terminal width
      def terminal_width
        @terminal_width ||= begin
          # Only use winsize if output is actually a TTY
          if output.respond_to?(:tty?) && output.tty? && output.respond_to?(:winsize)
            output.winsize[1]
          else
            DEFAULT_TERMINAL_WIDTH
          end
        rescue StandardError
          DEFAULT_TERMINAL_WIDTH
        end
      end

      # Truncate string with ellipsis
      def truncate_string(string, max_length)
        return string if string.length <= max_length

        "#{string[0...max_length - 3]}..."
      end

      # Build summary line
      def summary_line(summary)
        parts = []

        # Total examples
        total_text = "#{summary.example_count} examples"
        parts << colorize(total_text, :bright_white)

        # Failures
        if summary.failure_count.positive?
          failure_text = "#{summary.failure_count} failures"
          parts << colorize(failure_text, :red)
        end

        # Pending
        if summary.pending_count.positive?
          pending_text = "#{summary.pending_count} pending"
          parts << colorize(pending_text, :cyan)
        end

        # Passed
        passed_count = summary.example_count - summary.failure_count - summary.pending_count
        if passed_count.positive?
          passed_text = "#{passed_count} passed"
          parts << colorize(passed_text, :green)
        end

        parts.join(", ")
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

      # Format file location
      def format_location(example)
        "./#{example.metadata[:file_path]}:#{example.metadata[:line_number]}"
      end
    end
  end
end

# Register the formatter as ProgressBarFormatter for easier use
ProgressBarFormatter = Zenspec::Formatters::ProgressBarFormatter
