# frozen_string_literal: true

require "zenspec/formatters/progress_formatter"

RSpec.describe Zenspec::Formatters::ProgressFormatter do
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
      allow(execution_result).to receive(:exception).and_return(exception)
    end

    double("example",
           full_description: description,
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

  describe "#start" do
    it "initializes the progress loader" do
      notification = mock_notification(count: 10)

      # The start method should create a progress loader
      # but it doesn't render until the first example runs
      expect { formatter.start(notification) }.not_to raise_error
    end
  end

  describe "#example_passed" do
    before do
      formatter.start(mock_notification(count: 10))
      output.truncate(0)
      output.rewind
    end

    it "increments the progress" do
      example = mock_example
      notification = double("notification", example: example)

      formatter.example_passed(notification)

      expect(output.string).to include("1/10")
    end

    it "includes checkmark symbol" do
      example = mock_example
      notification = double("notification", example: example)

      formatter.example_passed(notification)

      expect(output.string).to include("✓")
    end
  end

  describe "#example_failed" do
    before do
      formatter.start(mock_notification(count: 10))
      output.truncate(0)
      output.rewind
    end

    it "increments the progress" do
      example = mock_example(status: :failed)
      notification = double("notification", example: example)

      formatter.example_failed(notification)

      expect(output.string).to include("1/10")
    end

    it "includes failure symbol" do
      example = mock_example(status: :failed)
      notification = double("notification", example: example)

      formatter.example_failed(notification)

      expect(output.string).to include("✗")
    end

    it "tracks failed examples" do
      example = mock_example(status: :failed)
      notification = double("notification", example: example)

      expect {
        formatter.example_failed(notification)
      }.to change { formatter.instance_variable_get(:@failed_examples).count }.by(1)
    end
  end

  describe "#example_pending" do
    before do
      formatter.start(mock_notification(count: 10))
      output.truncate(0)
      output.rewind
    end

    it "increments the progress" do
      example = mock_example
      notification = double("notification", example: example)

      formatter.example_pending(notification)

      expect(output.string).to include("1/10")
    end

    it "includes pending symbol" do
      example = mock_example
      notification = double("notification", example: example)

      formatter.example_pending(notification)

      expect(output.string).to include("*")
    end
  end

  describe "#dump_summary" do
    before do
      formatter.start(mock_notification(count: 10))
    end

    it "prints completion message" do
      summary = mock_summary(example_count: 10)
      formatter.dump_summary(summary)

      expect(output.string).to include("10 examples")
      expect(output.string).to include("Finished in")
    end

    it "includes failure count when present" do
      summary = mock_summary(example_count: 10, failure_count: 2)
      formatter.dump_summary(summary)

      expect(output.string).to include("2 failures")
    end

    it "includes pending count when present" do
      summary = mock_summary(example_count: 10, pending_count: 3)
      formatter.dump_summary(summary)

      expect(output.string).to include("3 pending")
    end

    it "lists pending examples" do
      example = mock_example(description: "pending test")
      formatter.example_pending(double("notification", example: example))

      summary = mock_summary(example_count: 10, pending_count: 1)
      formatter.dump_summary(summary)

      expect(output.string).to include("Pending examples:")
      expect(output.string).to include("pending test")
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

      notification = double("notification", example: example)
      formatter.example_failed(notification)

      failures_notification = double("notification", failed_examples: [example])
      formatter.dump_failures(failures_notification)

      output_string = output.string
      expect(output_string).to include("Failures:")
      expect(output_string).to include("failing test")
      expect(output_string).to include("./spec/failing_spec.rb:42")
    end

    it "does not print anything when no failures" do
      output.truncate(0)
      output.rewind

      failures_notification = double("notification", failed_examples: [])
      formatter.dump_failures(failures_notification)

      expect(output.string).to be_empty
    end
  end

  describe "integration" do
    it "provides complete test run output" do
      # Start
      formatter.start(mock_notification(count: 5))

      # Pass some examples
      2.times do |i|
        example = mock_example(description: "passing test #{i}")
        formatter.example_passed(double("notification", example: example))
      end

      # Fail one example
      failed_example = mock_example(description: "failing test", status: :failed)
      formatter.example_failed(double("notification", example: failed_example))

      # Pending one example
      pending_example = mock_example(description: "pending test")
      formatter.example_pending(double("notification", example: pending_example))

      # Pass one more
      example = mock_example(description: "final test")
      formatter.example_passed(double("notification", example: example))

      # Summary
      summary = mock_summary(example_count: 5, failure_count: 1, pending_count: 1)
      formatter.dump_summary(summary)

      # Failures
      failures_notification = double("notification", failed_examples: [failed_example])
      formatter.dump_failures(failures_notification)

      output_string = output.string

      # Verify key elements are present
      expect(output_string).to include("5/5")
      expect(output_string).to include("100%")
      expect(output_string).to include("Completed")
      expect(output_string).to include("5 examples")
      expect(output_string).to include("1 failure")
      expect(output_string).to include("1 pending")
      expect(output_string).to include("Failures:")
      expect(output_string).to include("failing test")
    end
  end
end
