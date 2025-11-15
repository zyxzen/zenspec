# frozen_string_literal: true

require "zenspec/formatters/progress_bar_formatter"

RSpec.describe Zenspec::Formatters::ProgressBarFormatter do
  let(:output) { StringIO.new }
  let(:formatter) { described_class.new(output) }

  # Helper to create a mock notification
  def mock_notification(count: 10)
    double("notification", count: count)
  end

  # Helper to create a mock example
  def mock_example(description: "test example", status: :passed, file_path: "spec/example_spec.rb", line_number: 10)
    execution_result = double("execution_result")

    if status == :failed
      exception = StandardError.new("Expected true but got false")
      allow(exception).to receive(:backtrace).and_return([
                                                            "spec/example_spec.rb:10:in `block'",
                                                            "spec/example_spec.rb:5:in `describe'"
                                                          ])
      allow(execution_result).to receive(:exception).and_return(exception)
    end

    double("example",
           description: description,
           full_description: "Example #{description}",
           metadata: {
             file_path: file_path,
             line_number: line_number
           },
           execution_result: execution_result)
  end

  # Helper to create a mock summary
  def mock_summary(example_count: 10, failure_count: 0, pending_count: 0, duration: 1.5)
    double("summary",
           example_count: example_count,
           failure_count: failure_count,
           pending_count: pending_count,
           duration: duration)
  end

  # Helper to strip ANSI codes
  def strip_ansi(text)
    text.gsub(/\e\[[0-9;]*m/, "")
  end

  # Helper to trigger file finalization by moving to a different file
  def finalize_current_file(formatter)
    different_file_example = mock_example(file_path: "spec/different_file_spec.rb")
    formatter.example_started(double("notification", example: different_file_example))
  end

  describe "#start" do
    it "initializes with total count" do
      notification = mock_notification(count: 20)
      expect { formatter.start(notification) }.not_to raise_error
    end

    it "prints initial newline" do
      notification = mock_notification(count: 10)
      formatter.start(notification)
      expect(output.string).to include("\n")
    end
  end

  describe "#example_started" do
    before do
      formatter.start(mock_notification(count: 10))
    end

    it "increments current count" do
      example = mock_example
      notification = double("notification", example: example)

      formatter.example_started(notification)

      expect(formatter.instance_variable_get(:@current_count)).to eq(1)
    end

    it "starts spinner thread" do
      example = mock_example
      notification = double("notification", example: example)

      formatter.example_started(notification)

      expect(formatter.instance_variable_get(:@spinner_running)).to be true
      expect(formatter.instance_variable_get(:@spinner_thread)).to be_a(Thread)
    end

    it "tracks current file" do
      example = mock_example(file_path: "spec/user_spec.rb")
      notification = double("notification", example: example)

      formatter.example_started(notification)

      expect(formatter.instance_variable_get(:@current_file)).to eq("user_spec.rb")
    end

    it "stores current test description in file state" do
      example = mock_example(description: "creates a new user", file_path: "spec/user_spec.rb")
      notification = double("notification", example: example)

      formatter.example_started(notification)

      file_states = formatter.instance_variable_get(:@file_states)
      expect(file_states["user_spec.rb"][:current_test]).to eq("creates a new user")
    end

    it "shows spinner output after thread updates" do
      example = mock_example(file_path: "spec/user_spec.rb", description: "test description")
      notification = double("notification", example: example)

      formatter.example_started(notification)
      sleep 0.15 # Allow spinner thread to update at least once

      # Should include one of the spinner frames
      spinner_frames = described_class::SPINNER_FRAMES
      output_text = strip_ansi(output.string)
      expect(spinner_frames.any? { |frame| output_text.include?(frame) }).to be true
    end
  end

  describe "#example_passed" do
    before do
      formatter.start(mock_notification(count: 10))
    end

    it "increments passed count for the file" do
      example = mock_example(file_path: "spec/user_spec.rb")
      formatter.example_started(double("notification", example: example))
      formatter.example_passed(double("notification", example: example))

      file_states = formatter.instance_variable_get(:@file_states)
      expect(file_states["user_spec.rb"][:passed]).to eq(1)
    end

    it "clears current test description" do
      example = mock_example(file_path: "spec/user_spec.rb", description: "test")
      formatter.example_started(double("notification", example: example))
      formatter.example_passed(double("notification", example: example))

      file_states = formatter.instance_variable_get(:@file_states)
      expect(file_states["user_spec.rb"][:current_test]).to be_nil
    end
  end

  describe "#example_failed" do
    before do
      formatter.start(mock_notification(count: 10))
    end

    it "increments failed count for the file" do
      example = mock_example(file_path: "spec/user_spec.rb", status: :failed)
      formatter.example_started(double("notification", example: example))
      formatter.example_failed(double("notification", example: example))

      file_states = formatter.instance_variable_get(:@file_states)
      expect(file_states["user_spec.rb"][:failed]).to eq(1)
    end

    it "tracks failed examples" do
      example = mock_example(status: :failed)
      notification = double("notification", example: example)

      formatter.example_started(double("notification", example: example))

      expect {
        formatter.example_failed(notification)
      }.to change { formatter.instance_variable_get(:@failed_examples).count }.by(1)
    end
  end

  describe "#example_pending" do
    before do
      formatter.start(mock_notification(count: 10))
    end

    it "increments pending count for the file" do
      example = mock_example(file_path: "spec/user_spec.rb")
      formatter.example_started(double("notification", example: example))
      formatter.example_pending(double("notification", example: example))

      file_states = formatter.instance_variable_get(:@file_states)
      expect(file_states["user_spec.rb"][:pending]).to eq(1)
    end

    it "tracks pending examples" do
      example = mock_example
      notification = double("notification", example: example)

      formatter.example_started(double("notification", example: example))

      expect {
        formatter.example_pending(notification)
      }.to change { formatter.instance_variable_get(:@pending_examples).count }.by(1)
    end
  end

  describe "file finalization" do
    before do
      formatter.start(mock_notification(count: 10))
    end

    it "prints passed icon (✔) when file is done with all tests passing" do
      example1 = mock_example(file_path: "spec/user_spec.rb", description: "test 1")
      example2 = mock_example(file_path: "spec/user_spec.rb", description: "test 2")

      formatter.example_started(double("notification", example: example1))
      formatter.example_passed(double("notification", example: example1))

      formatter.example_started(double("notification", example: example2))
      formatter.example_passed(double("notification", example: example2))

      output.truncate(0)
      output.rewind

      # Trigger finalization by moving to different file
      finalize_current_file(formatter)

      expect(strip_ansi(output.string)).to include("✔")
    end

    it "prints failed icon (✗) when file has any failures" do
      example1 = mock_example(file_path: "spec/user_spec.rb", description: "test 1")
      example2 = mock_example(file_path: "spec/user_spec.rb", description: "test 2", status: :failed)

      formatter.example_started(double("notification", example: example1))
      formatter.example_passed(double("notification", example: example1))

      formatter.example_started(double("notification", example: example2))
      formatter.example_failed(double("notification", example: example2))

      output.truncate(0)
      output.rewind

      # Trigger finalization
      finalize_current_file(formatter)

      expect(strip_ansi(output.string)).to include("✗")
    end

    it "prints pending icon (⊘) when file has pending tests but no failures" do
      example1 = mock_example(file_path: "spec/user_spec.rb", description: "test 1")
      example2 = mock_example(file_path: "spec/user_spec.rb", description: "test 2")

      formatter.example_started(double("notification", example: example1))
      formatter.example_passed(double("notification", example: example1))

      formatter.example_started(double("notification", example: example2))
      formatter.example_pending(double("notification", example: example2))

      output.truncate(0)
      output.rewind

      # Trigger finalization
      finalize_current_file(formatter)

      expect(strip_ansi(output.string)).to include("⊘")
    end

    it "includes filename in finalized output" do
      example = mock_example(file_path: "spec/user_spec.rb")

      formatter.example_started(double("notification", example: example))
      formatter.example_passed(double("notification", example: example))

      output.truncate(0)
      output.rewind

      finalize_current_file(formatter)

      expect(strip_ansi(output.string)).to include("user_spec.rb")
    end

    it "does not include test description in finalized output" do
      example = mock_example(file_path: "spec/user_spec.rb", description: "creates a new user")

      formatter.example_started(double("notification", example: example))
      formatter.example_passed(double("notification", example: example))

      output.truncate(0)
      output.rewind

      finalize_current_file(formatter)

      expect(strip_ansi(output.string)).not_to include("creates a new user")
    end

    it "does not include arrow separator (-->) in finalized output" do
      example = mock_example(file_path: "spec/user_spec.rb")

      formatter.example_started(double("notification", example: example))
      formatter.example_passed(double("notification", example: example))

      output.truncate(0)
      output.rewind

      finalize_current_file(formatter)

      expect(strip_ansi(output.string)).not_to include("-->")
    end

    it "includes progress percentage in finalized output" do
      example = mock_example(file_path: "spec/user_spec.rb")

      formatter.example_started(double("notification", example: example))
      formatter.example_passed(double("notification", example: example))

      output.truncate(0)
      output.rewind

      finalize_current_file(formatter)

      expect(strip_ansi(output.string)).to match(/\[\d+% \d+\/10\]/)
    end

    it "ends with newline in finalized output" do
      example = mock_example(file_path: "spec/user_spec.rb")

      formatter.example_started(double("notification", example: example))
      formatter.example_passed(double("notification", example: example))

      output.truncate(0)
      output.rewind

      finalize_current_file(formatter)
      sleep 0.1 # Allow spinner to update for the new file

      # The finalized line should be present with a newline
      # (even though spinner output for the new file comes after without newline)
      lines = output.string.split("\n")
      expect(lines.any? { |line| strip_ansi(line).include?("user_spec.rb") }).to be true
    end
  end

  describe "#dump_summary" do
    before do
      formatter.start(mock_notification(count: 10))
    end

    it "stops the spinner thread" do
      example = mock_example
      formatter.example_started(double("notification", example: example))

      expect(formatter.instance_variable_get(:@spinner_running)).to be true

      summary = mock_summary(example_count: 10)
      formatter.dump_summary(summary)

      expect(formatter.instance_variable_get(:@spinner_running)).to be false
      expect(formatter.instance_variable_get(:@spinner_thread)).to be_nil
    end

    it "prints test summary header" do
      summary = mock_summary(example_count: 10)
      formatter.dump_summary(summary)

      expect(strip_ansi(output.string)).to include("Test Summary")
    end

    it "includes total examples count" do
      summary = mock_summary(example_count: 15)
      formatter.dump_summary(summary)

      expect(strip_ansi(output.string)).to include("15 examples")
    end

    it "includes failure count when present" do
      summary = mock_summary(example_count: 10, failure_count: 3)
      formatter.dump_summary(summary)

      expect(strip_ansi(output.string)).to include("3 failures")
    end

    it "includes pending count when present" do
      summary = mock_summary(example_count: 10, pending_count: 2)
      formatter.dump_summary(summary)

      expect(strip_ansi(output.string)).to include("2 pending")
    end

    it "includes passed count" do
      summary = mock_summary(example_count: 10, failure_count: 2, pending_count: 1)
      formatter.dump_summary(summary)

      # 10 - 2 - 1 = 7 passed
      expect(strip_ansi(output.string)).to include("7 passed")
    end

    it "includes duration" do
      summary = mock_summary(duration: 2.5)
      formatter.dump_summary(summary)

      expect(strip_ansi(output.string)).to include("Duration:")
    end

    it "lists pending examples when present" do
      example = mock_example(description: "pending test")
      formatter.example_started(double("notification", example: example))
      formatter.example_pending(double("notification", example: example))

      summary = mock_summary(example_count: 10, pending_count: 1)
      formatter.dump_summary(summary)

      expect(strip_ansi(output.string)).to include("Pending Examples:")
      expect(strip_ansi(output.string)).to include("pending test")
    end
  end

  describe "#dump_failures" do
    before do
      formatter.start(mock_notification(count: 10))
    end

    it "prints failure details" do
      example = mock_example(
        description: "failing test",
        status: :failed,
        file_path: "spec/failing_spec.rb",
        line_number: 42
      )

      start_notification = double("notification", example: example)
      formatter.example_started(start_notification)

      fail_notification = double("notification", example: example)
      formatter.example_failed(fail_notification)

      failures_notification = double("notification", failed_examples: [example])
      formatter.dump_failures(failures_notification)

      output_string = strip_ansi(output.string)
      expect(output_string).to include("Failures:")
      expect(output_string).to include("failing test")
      expect(output_string).to include("./spec/failing_spec.rb:42")
    end

    it "includes exception message" do
      example = mock_example(status: :failed)

      formatter.example_started(double("notification", example: example))
      formatter.example_failed(double("notification", example: example))

      failures_notification = double("notification", failed_examples: [example])
      formatter.dump_failures(failures_notification)

      expect(strip_ansi(output.string)).to include("Expected true but got false")
    end

    it "does not print anything when no failures" do
      output.truncate(0)
      output.rewind

      failures_notification = double("notification", failed_examples: [])
      formatter.dump_failures(failures_notification)

      expect(output.string).to be_empty
    end
  end

  describe "color codes" do
    before do
      formatter.start(mock_notification(count: 10))
    end

    it "uses green for passed files" do
      example = mock_example(file_path: "spec/user_spec.rb")
      formatter.example_started(double("notification", example: example))
      formatter.example_passed(double("notification", example: example))

      output.truncate(0)
      output.rewind

      finalize_current_file(formatter)

      # Check for green ANSI code
      expect(output.string).to include("\e[32m")
    end

    it "uses red for failed files" do
      example = mock_example(file_path: "spec/user_spec.rb", status: :failed)
      formatter.example_started(double("notification", example: example))
      formatter.example_failed(double("notification", example: example))

      output.truncate(0)
      output.rewind

      finalize_current_file(formatter)

      # Check for red ANSI code
      expect(output.string).to include("\e[31m")
    end

    it "uses yellow for running tests" do
      example = mock_example(file_path: "spec/user_spec.rb")
      formatter.example_started(double("notification", example: example))
      sleep 0.15 # Allow spinner to update

      # Check for yellow ANSI code
      expect(output.string).to include("\e[33m")
    end

    it "uses cyan for pending files" do
      example = mock_example(file_path: "spec/user_spec.rb")
      formatter.example_started(double("notification", example: example))
      formatter.example_pending(double("notification", example: example))

      output.truncate(0)
      output.rewind

      finalize_current_file(formatter)

      # Check for cyan ANSI code
      expect(output.string).to include("\e[36m")
    end
  end

  describe "spinner animation" do
    before do
      formatter.start(mock_notification(count: 10))
    end

    it "cycles through spinner frames" do
      example = mock_example(file_path: "spec/user_spec.rb", description: "test")
      formatter.example_started(double("notification", example: example))

      # Wait for multiple spinner updates
      sleep 0.25

      # Should have updated the output with spinner frames
      spinner_frames = described_class::SPINNER_FRAMES
      output_text = strip_ansi(output.string)
      expect(spinner_frames.any? { |frame| output_text.include?(frame) }).to be true
    end

    it "includes test description while running" do
      example = mock_example(file_path: "spec/user_spec.rb", description: "creates a new user")
      formatter.example_started(double("notification", example: example))

      sleep 0.15 # Allow spinner to update

      expect(strip_ansi(output.string)).to include("creates a new user")
    end

    it "includes arrow separator (-->) while running" do
      example = mock_example(file_path: "spec/user_spec.rb")
      formatter.example_started(double("notification", example: example))

      sleep 0.15 # Allow spinner to update

      expect(strip_ansi(output.string)).to include("-->")
    end
  end

  describe "line formatting" do
    before do
      formatter.start(mock_notification(count: 10))
    end

    it "truncates long descriptions to fit terminal width" do
      long_description = "a" * 200
      example = mock_example(description: long_description, file_path: "spec/user_spec.rb")

      formatter.example_started(double("notification", example: example))
      sleep 0.15 # Allow spinner to update

      # The output should not be longer than terminal width
      visual_output = strip_ansi(output.string.split("\r").last || "")
      expect(visual_output.length).to be <= described_class::DEFAULT_TERMINAL_WIDTH + 5
    end

    it "includes ellipsis when truncating" do
      long_description = "a" * 200
      example = mock_example(description: long_description, file_path: "spec/user_spec.rb")

      formatter.example_started(double("notification", example: example))
      sleep 0.15 # Allow spinner to update

      expect(strip_ansi(output.string)).to include("...")
    end
  end
end
