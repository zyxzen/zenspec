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

  # Minimal ActiveRecord-like double for the record-based matchers
  class FakeRecord
    class << self
      attr_accessor :existing_ids
    end
    self.existing_ids = []

    def self.exists?(id)
      existing_ids.include?(id)
    end

    attr_accessor :id, :name, :is_active

    def initialize(id:, name: nil, is_active: nil, persisted: true)
      @id = id
      @name = name
      @is_active = is_active
      @destroyed = false
      @persisted = persisted
      self.class.existing_ids << id if persisted
    end

    def persisted?
      @persisted
    end

    def destroyed?
      @destroyed
    end

    def destroy
      @destroyed = true
      @persisted = false
      self.class.existing_ids.delete(@id)
    end

    def reload
      self
    end

    def present?
      !@destroyed
    end
  end

  describe "succeed.with_persisted_data" do
    class PersistedDataInteractor
      include Interactor

      def call
        context.data = FakeRecord.new(id: 1, name: "ok")
      end
    end

    class UnpersistedDataInteractor
      include Interactor

      def call
        context.data = FakeRecord.new(id: 2, name: "draft", persisted: false)
      end
    end

    class NilDataInteractor
      include Interactor

      def call
        context.data = nil
      end
    end

    it "matches when data is a persisted record" do
      expect(PersistedDataInteractor.call).to succeed.with_persisted_data
    end

    it "works with the interactor class directly" do
      expect(PersistedDataInteractor).to succeed.with_persisted_data
    end

    it "fails with a clear message when data is not persisted" do
      expect do
        expect(UnpersistedDataInteractor.call).to succeed.with_persisted_data
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /was not/)
    end

    it "fails when data is nil" do
      expect do
        expect(NilDataInteractor.call).to succeed.with_persisted_data
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /nil/)
    end

    it "supports negation" do
      expect(UnpersistedDataInteractor.call).not_to succeed.with_persisted_data
    end
  end

  describe "succeed.with_data_type" do
    class StringDataInteractor
      include Interactor

      def call
        context.data = "hello"
      end
    end

    class RecordDataInteractor
      include Interactor

      def call
        context.data = FakeRecord.new(id: 10, name: "thing")
      end
    end

    it "matches when data is an instance of the expected class" do
      expect(StringDataInteractor.call).to succeed.with_data_type(String)
    end

    it "matches subclasses / module ancestry" do
      expect(RecordDataInteractor.call).to succeed.with_data_type(FakeRecord)
    end

    it "fails with a clear message when data is not the expected type" do
      expect do
        expect(StringDataInteractor.call).to succeed.with_data_type(Integer)
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /kind of Integer/)
    end

    it "supports negation" do
      expect(StringDataInteractor.call).not_to succeed.with_data_type(Integer)
    end
  end

  describe "destroy_record matcher" do
    it "matches when destroyed? is true" do
      record = FakeRecord.new(id: 100, name: "to-remove")
      record.destroy
      expect(record).to destroy_record(record)
    end

    it "matches when the class no longer reports the record as existing" do
      record = FakeRecord.new(id: 101, name: "gone")
      FakeRecord.existing_ids.delete(101)
      # record.destroyed? is still false here, but exists? returns false
      expect(record).to destroy_record(record)
    end

    it "fails with a clear message when the record still exists" do
      record = FakeRecord.new(id: 102, name: "alive")
      expect do
        expect(record).to destroy_record(record)
      end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /still exists/)
    end

    it "supports negation" do
      record = FakeRecord.new(id: 103, name: "alive")
      expect(record).not_to destroy_record(record)
    end

    it "invokes the interactor class when given one" do
      record = FakeRecord.new(id: 104, name: "to-remove-by-class")
      destroyer = Class.new do
        include Interactor

        class << self
          attr_writer :target
        end

        class << self
          attr_reader :target
        end

        def call
          self.class.target.destroy
        end
      end
      destroyer.target = record
      expect(destroyer).to destroy_record(record)
    end
  end

  describe "update_record matcher" do
    it "matches when the attributes match after running" do
      record = FakeRecord.new(id: 200, name: "old", is_active: false)
      record.name = "new"
      record.is_active = true
      expect(record).to update_record(record).with(name: "new", is_active: true)
    end

    it "fails with a clear message listing the mismatched attributes" do
      record = FakeRecord.new(id: 201, name: "still-old", is_active: false)
      expect do
        expect(record).to update_record(record).with(name: "new", is_active: true)
      end.to raise_error(
        RSpec::Expectations::ExpectationNotMetError,
        /name: expected "new", got "still-old".*is_active: expected true, got false/m
      )
    end

    it "supports negation" do
      record = FakeRecord.new(id: 202, name: "untouched")
      expect(record).not_to update_record(record).with(name: "changed")
    end

    it "invokes the interactor class when given one" do
      record = FakeRecord.new(id: 203, name: "before")
      updater = Class.new do
        include Interactor

        class << self
          attr_writer :target
        end

        class << self
          attr_reader :target
        end

        def call
          self.class.target.name = "after"
        end
      end
      updater.target = record
      expect(updater).to update_record(record).with(name: "after")
    end
  end
end
