require "test_helper"

class TokenFilterTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Compositions::Components::Filter.new(:podcast_id)
    @model.operator = :include
    @model.values = [1, 2, 3]
  end

  test "valid construction" do
    assert @model.valid?
  end

  test "is invalid with no values" do
    @model.values = nil
    @model.validate
    assert @model.errors.added?(:values, :missing_values)
  end

  test "is invalid with empty values" do
    @model.values = []
    @model.validate
    assert @model.errors.added?(:values, :missing_values)
  end

  test "is invalid with extract" do
    @model.extract = :hour
    @model.validate
    assert @model.errors.added?(:extract, :invalid_option)
  end

  test "is invalid with from" do
    @model.from = "now"
    @model.validate
    assert @model.errors.added?(:from, :invalid_option)
  end

  test "is invalid with to" do
    @model.to = "now"
    @model.validate
    assert @model.errors.added?(:to, :invalid_option)
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
