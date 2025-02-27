require "test_helper"

class FilterTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Compositions::Components::Filter.new(:podcast_id)
    @model.operator = :include
    @model.values = [1, 2, 3]
  end

  test "missing operator" do
    assert_raises(RuntimeError) do
      @model.operator = nil
    end

    filter = Compositions::Components::Filter.new(:podcast_id)
    filter.validate
    assert filter.errors.include?(:operator)
  end

  test "invalid operator" do
    @model.operator = :bogus
    @model.validate
    assert @model.errors.include?(:operator)
  end

  test "invalid dimension" do
    filter = Compositions::Components::Filter.new(:bogus)
    filter.operator = :include
    filter.values = [1, 2, 3]
    filter.validate

    assert filter.errors.added?(:dimension, :invalid_dimension)
  end
end
