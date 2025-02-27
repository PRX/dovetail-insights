require "test_helper"

class TimestampRangeFilterTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Compositions::Components::Filter.new(:episode_publish_timestamp)
    @model.operator = :include
    @model.from = "now-7/D"
    @model.to = "now"
  end

  test "valid construction" do
    assert @model.valid?
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

  test "is invalid with values" do
    @model.values = [1, 2, 3]
    @model.validate
    assert @model.errors.added?(:values, :invalid_option)
  end

  test "is invalid with extract" do
    @model.extract = :hour
    @model.validate
    assert @model.errors.added?(:extract, :invalid_option)
  end
end
