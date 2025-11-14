# frozen_string_literal: true

require "interactor"

# Simple test to verify interactor matchers work correctly
RSpec.describe "Interactor Matchers" do
  # Create simple test interactors
  class TestSuccessInteractor
    include Interactor

    def call
      context.data = "success data"
      context.custom_value = 42
    end
  end

  class TestFailureInteractor
    include Interactor

    def call
      context.fail!(errors: [{ code: "TEST_ERROR" }, { code: "ANOTHER_ERROR" }])
    end
  end

  describe "succeed matcher" do
    it "matches successful interactor" do
      result = TestSuccessInteractor.call
      expect(result).to succeed
    end

    it "matches with data" do
      result = TestSuccessInteractor.call
      expect(result).to succeed.with_data("success data")
    end

    it "matches with context" do
      result = TestSuccessInteractor.call
      expect(result).to succeed.with_context(:custom_value, 42)
    end

    it "works with interactor class directly" do
      expect(TestSuccessInteractor).to succeed
    end

    it "fails when interactor fails" do
      result = TestFailureInteractor.call
      expect(result).not_to succeed
    end
  end

  describe "fail_interactor matcher" do
    it "matches failed interactor" do
      result = TestFailureInteractor.call
      expect(result).to fail_interactor
    end

    it "matches with single error" do
      result = TestFailureInteractor.call
      expect(result).to fail_interactor.with_error("TEST_ERROR")
    end

    it "matches with multiple errors" do
      result = TestFailureInteractor.call
      expect(result).to fail_interactor.with_errors("TEST_ERROR", "ANOTHER_ERROR")
    end

    it "works with interactor class directly" do
      expect(TestFailureInteractor).to fail_interactor.with_error("TEST_ERROR")
    end

    it "fails when interactor succeeds" do
      result = TestSuccessInteractor.call
      expect(result).not_to fail_interactor
    end
  end

  describe "have_error_code matcher" do
    it "matches when error code exists" do
      result = TestFailureInteractor.call
      expect(result).to have_error_code("TEST_ERROR")
    end

    it "fails when error code does not exist" do
      result = TestFailureInteractor.call
      expect(result).not_to have_error_code("NONEXISTENT_ERROR")
    end
  end

  describe "have_error_codes matcher" do
    it "matches when all error codes exist" do
      result = TestFailureInteractor.call
      expect(result).to have_error_codes("TEST_ERROR", "ANOTHER_ERROR")
    end

    it "fails when not all error codes exist" do
      result = TestFailureInteractor.call
      expect(result).not_to have_error_codes("TEST_ERROR", "NONEXISTENT_ERROR")
    end
  end

  describe "set_context matcher" do
    it "matches when context key is set" do
      result = TestSuccessInteractor.call
      expect(result).to set_context(:data)
    end

    it "matches with value" do
      result = TestSuccessInteractor.call
      expect(result).to set_context(:data, "success data")
    end

    it "works with to chain" do
      result = TestSuccessInteractor.call
      expect(result).to set_context(:custom_value).to(42)
    end

    it "fails when context key is not set" do
      result = TestSuccessInteractor.call
      expect(result).not_to set_context(:nonexistent_key)
    end
  end
end
