#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script for Zenspec::ProgressLoader
# This script demonstrates the Docker-style progress loader

require_relative "../lib/zenspec/progress_loader"

puts "=== Zenspec ProgressLoader Demo ==="
puts
puts "This demo shows Docker-style progress bars in action."
puts

# Demo 1: Basic progress loader
puts "Demo 1: Basic file processing"
puts "-" * 50
loader = Zenspec::ProgressLoader.new(
  total: 20,
  description: "Processing files"
)

20.times do |i|
  loader.update(i + 1, description: "Processing file_#{i + 1}.txt")
  sleep(0.1)
end

loader.finish(description: "All files processed!")
puts
puts

# Demo 2: Downloading layers (Docker-style)
puts "Demo 2: Downloading Docker layers"
puts "-" * 50
layers = 5
loader = Zenspec::ProgressLoader.new(
  total: layers,
  description: "Downloading image"
)

layers.times do |i|
  layer_id = "sha256:#{rand(16**12).to_s(16).rjust(12, '0')}"
  loader.update(i + 1, description: "Downloading layer #{i + 1}/#{layers}: #{layer_id[0..19]}...")
  sleep(0.3)
end

loader.finish(description: "Image downloaded successfully!")
puts
puts

# Demo 3: Custom width progress bar
puts "Demo 3: Wide progress bar"
puts "-" * 50
loader = Zenspec::ProgressLoader.new(
  total: 50,
  width: 60,
  description: "Running tests"
)

50.times do |i|
  loader.update(i + 1, description: "Test #{i + 1}/50")
  sleep(0.05)
end

loader.finish(description: "All tests passed!")
puts
puts

# Demo 4: Increment usage
puts "Demo 4: Using increment method"
puts "-" * 50
loader = Zenspec::ProgressLoader.new(
  total: 10,
  description: "Building packages"
)

packages = %w[auth api web worker scheduler mailer notifications cache database utils]

packages.each_with_index do |package, i|
  loader.increment(description: "Building #{package} package...")
  sleep(0.2)
end

loader.finish(description: "Build complete!")
puts
puts

# Demo 5: Fast progress with many items
puts "Demo 5: Fast progress (1000 items)"
puts "-" * 50
loader = Zenspec::ProgressLoader.new(
  total: 1000,
  description: "Processing records"
)

1000.times do |i|
  loader.update(i + 1)
  # Very fast, only update display every 10 items
  sleep(0.001) if (i + 1) % 10 == 0
end

loader.finish(description: "1000 records processed!")
puts
puts

puts "=== Demo Complete ==="
puts
puts "The ProgressLoader can be used for:"
puts "  • Test suite progress (RSpec formatter)"
puts "  • File processing operations"
puts "  • Docker-style layer downloads"
puts "  • Database migrations"
puts "  • Batch processing tasks"
puts "  • Any long-running terminal operations"
