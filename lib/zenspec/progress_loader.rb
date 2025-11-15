# frozen_string_literal: true

module Zenspec
  # Docker-style progress loader for displaying progress in terminal
  # Displays progress bars similar to Docker's layer download progress
  #
  # @example Basic usage
  #   loader = Zenspec::ProgressLoader.new(total: 10, description: "Running tests")
  #   10.times do |i|
  #     loader.update(i + 1)
  #     sleep(0.1)
  #   end
  #   loader.finish
  #
  # @example With custom width
  #   loader = Zenspec::ProgressLoader.new(total: 100, width: 50)
  #   loader.update(50, description: "Processing files 50/100")
  #
  class ProgressLoader
    attr_reader :current, :total, :width

    # Default width for the progress bar
    DEFAULT_WIDTH = 40

    # @param total [Integer] Total number of items to process
    # @param width [Integer] Width of the progress bar in characters
    # @param description [String] Initial description text
    # @param output [IO] Output stream (defaults to STDERR)
    def initialize(total:, width: DEFAULT_WIDTH, description: nil, output: $stderr)
      @total = total
      @width = width
      @current = 0
      @description = description
      @output = output
      @finished = false
      @start_time = Time.now
    end

    # Update the progress
    # @param current [Integer] Current progress value
    # @param description [String, nil] Optional description to display
    def update(current, description: nil)
      @current = current
      @description = description if description
      render unless @finished
    end

    # Increment progress by one
    # @param description [String, nil] Optional description to display
    def increment(description: nil)
      update(@current + 1, description: description)
    end

    # Mark the progress as finished
    # @param description [String, nil] Final description to display
    def finish(description: nil)
      @current = @total
      @description = description if description
      @finished = true
      render
      @output.puts # New line after completion
    end

    # Calculate current percentage
    # @return [Integer] Percentage (0-100)
    def percentage
      return 100 if @total.zero?

      ((@current.to_f / @total) * 100).round
    end

    # Calculate elapsed time
    # @return [Float] Elapsed time in seconds
    def elapsed_time
      Time.now - @start_time
    end

    # Calculate estimated time remaining
    # @return [Float, nil] Estimated time remaining in seconds, or nil if cannot estimate
    def estimated_time_remaining
      return nil if @current.zero?

      elapsed = elapsed_time
      rate = @current.to_f / elapsed
      remaining_items = @total - @current
      remaining_items / rate
    end

    # Format time duration
    # @param seconds [Float] Time in seconds
    # @return [String] Formatted time string
    def format_time(seconds)
      return "0s" if seconds.nil? || seconds.zero?

      if seconds < 60
        "#{seconds.round}s"
      elsif seconds < 3600
        minutes = (seconds / 60).round
        "#{minutes}m"
      else
        hours = (seconds / 3600).round
        "#{hours}h"
      end
    end

    private

    # Render the progress bar
    def render
      bar = build_progress_bar
      counter = "#{@current}/#{@total}"
      percent = "#{percentage}%"
      time_info = build_time_info

      # Build the complete line
      parts = [bar, percent, counter]
      parts << @description if @description
      parts << time_info if time_info && !@finished

      line = parts.join(" ")

      # Clear the line and print
      @output.print "\r\e[K#{line}"
      @output.flush
    end

    # Build the progress bar string
    # @return [String] Progress bar visualization
    def build_progress_bar
      return "[#{' ' * @width}]" if @total.zero?

      filled_width = ((@current.to_f / @total) * @width).round
      empty_width = @width - filled_width

      filled = "=" * [filled_width - 1, 0].max
      arrow = filled_width.positive? ? ">" : ""
      empty = " " * empty_width

      "[#{filled}#{arrow}#{empty}]"
    end

    # Build time information string
    # @return [String, nil] Time information or nil
    def build_time_info
      elapsed = elapsed_time
      remaining = estimated_time_remaining

      if remaining && remaining.positive?
        "#{format_time(elapsed)}/#{format_time(remaining + elapsed)}"
      elsif elapsed > 1 # Only show elapsed if more than 1 second
        format_time(elapsed)
      end
    end
  end
end
