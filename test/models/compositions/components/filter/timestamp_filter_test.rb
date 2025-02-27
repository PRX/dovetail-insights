require "test_helper"

class TimestampFilterTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Compositions::Components::Filter.new(:episode_publish_timestamp)
    @model.operator = :include
  end

  test "is invalid with no options" do
    @model.validate
    assert @model.errors.added?(:dimension, :invalid_option)
  end

  test "is invalid with multiple options" do
    @model.extract = :hour
    @model.from = "now"
    @model.validate
    assert @model.errors.added?(:extract, :invalid_option)
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
