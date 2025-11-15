# frozen_string_literal: true

RSpec.describe Zenspec::ProgressLoader do
  let(:output) { StringIO.new }
  let(:loader) { described_class.new(total: total, output: output) }
  let(:total) { 10 }

  describe "#initialize" do
    it "sets the total" do
      expect(loader.total).to eq(10)
    end

    it "starts with current at 0" do
      expect(loader.current).to eq(0)
    end

    it "uses default width" do
      expect(loader.width).to eq(described_class::DEFAULT_WIDTH)
    end

    it "accepts custom width" do
      custom_loader = described_class.new(total: 10, width: 50, output: output)
      expect(custom_loader.width).to eq(50)
    end
  end

  describe "#update" do
    it "updates the current value" do
      loader.update(5)
      expect(loader.current).to eq(5)
    end

    it "updates the description" do
      loader.update(5, description: "Processing files")
      output_string = output.string
      expect(output_string).to include("Processing files")
    end

    it "renders progress to output" do
      loader.update(5)
      expect(output.string).not_to be_empty
    end
  end

  describe "#increment" do
    it "increments the current value by 1" do
      loader.increment
      expect(loader.current).to eq(1)

      loader.increment
      expect(loader.current).to eq(2)
    end

    it "accepts a description" do
      loader.increment(description: "Step 1")
      expect(output.string).to include("Step 1")
    end
  end

  describe "#finish" do
    it "sets current to total" do
      loader.update(5)
      loader.finish
      expect(loader.current).to eq(total)
    end

    it "outputs a newline" do
      loader.finish
      expect(output.string).to end_with("\n")
    end

    it "accepts a final description" do
      loader.finish(description: "Complete!")
      expect(output.string).to include("Complete!")
    end
  end

  describe "#percentage" do
    it "returns 0 when current is 0" do
      expect(loader.percentage).to eq(0)
    end

    it "returns 50 when halfway" do
      loader.update(5)
      expect(loader.percentage).to eq(50)
    end

    it "returns 100 when complete" do
      loader.update(10)
      expect(loader.percentage).to eq(100)
    end

    it "returns 100 when total is 0" do
      zero_loader = described_class.new(total: 0, output: output)
      expect(zero_loader.percentage).to eq(100)
    end
  end

  describe "#elapsed_time" do
    it "returns elapsed time in seconds" do
      # Just check that it returns a positive number
      expect(loader.elapsed_time).to be_a(Float)
      expect(loader.elapsed_time).to be >= 0
    end
  end

  describe "#estimated_time_remaining" do
    it "returns nil when current is 0" do
      expect(loader.estimated_time_remaining).to be_nil
    end

    it "estimates remaining time based on current progress" do
      loader.update(5)
      sleep(0.1)
      remaining = loader.estimated_time_remaining
      expect(remaining).to be_a(Float)
      expect(remaining).to be > 0
    end
  end

  describe "#format_time" do
    it "formats seconds" do
      expect(loader.format_time(30)).to eq("30s")
    end

    it "formats minutes" do
      expect(loader.format_time(120)).to eq("2m")
    end

    it "formats hours" do
      expect(loader.format_time(7200)).to eq("2h")
    end

    it "handles zero" do
      expect(loader.format_time(0)).to eq("0s")
    end

    it "handles nil" do
      expect(loader.format_time(nil)).to eq("0s")
    end
  end

  describe "progress bar rendering" do
    it "includes percentage" do
      loader.update(5)
      expect(output.string).to match(/50%/)
    end

    it "includes counter" do
      loader.update(5)
      expect(output.string).to match(/5\/10/)
    end

    it "includes progress bar brackets" do
      loader.update(5)
      expect(output.string).to include("[")
      expect(output.string).to include("]")
    end

    it "shows arrow in progress bar when progressing" do
      loader.update(5)
      expect(output.string).to include(">")
    end

    it "fills progress bar appropriately" do
      loader.update(10)
      output_string = output.string
      # At 100%, the bar should be mostly filled with '='
      expect(output_string).to include("=")
    end
  end

  describe "Docker-style output format" do
    it "matches Docker-style pattern" do
      loader.update(7, description: "Downloading layer 7/10")
      output_string = output.string

      # Should contain: [progress bar] percentage counter description
      expect(output_string).to match(/\[.*\]/)  # Progress bar
      expect(output_string).to match(/70%/)      # Percentage
      expect(output_string).to match(/7\/10/)    # Counter
      expect(output_string).to include("Downloading layer 7/10") # Description
    end
  end
end
