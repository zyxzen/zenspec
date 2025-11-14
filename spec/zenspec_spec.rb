# frozen_string_literal: true

RSpec.describe Zenspec do
  it "has a version number" do
    expect(Zenspec::VERSION).not_to be nil
  end

  it "loads matchers module" do
    expect(Zenspec::Matchers).to be_a(Module)
  end
end
