require "test_helper"

class TimestampExtractFilterTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Compositions::Components::Filter.new(:episode_publish_timestamp)
    @model.operator = :include
    @model.extract = :hour
    @model.values = [1, 2, 22, 23]
  end

  test "valid construction" do
    assert @model.valid?
  end

  test "invalid extract" do
    @model.extract = :bogus
    @model.validate
    assert @model.errors.added?(:extract, :bad_extract)
  end

  test "missing values" do
    @model.values = nil
    @model.validate
    assert @model.errors.added?(:values, :missing_values)
  end

  test "empty values" do
    @model.values = []
    @model.validate
    assert @model.errors.added?(:values, :missing_values)
  end

  test "is invalid with from" do
    @model.from = "now"
    @model.validate
    assert @model.errors.added?(:extract, :invalid_option)
    assert @model.errors.added?(:values, :invalid_option)
  end

  test "is invalid with to" do
    @model.to = "now"
    @model.validate
    assert @model.errors.added?(:extract, :invalid_option)
    assert @model.errors.added?(:values, :invalid_option)
  end

  test "is invalid with gte" do
    @model.gte = 0
    @model.validate
    assert @model.errors.added?(:gte, :invalid_option)
  end

  test "is invalid with lt" do
    @model.lt = 999
    @model.validate
    assert @model.errors.added?(:lt, :invalid_option)
  end
end
