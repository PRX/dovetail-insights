require "test_helper"

class DurationFilterTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Compositions::Components::Filter.new(:current_episode_age_in_seconds)
    @model.operator = :include
    @model.gte = 10
    @model.lt = 999
  end

  test "valid construction" do
    assert @model.valid?
  end

  test "shorthand expansion" do
    params = ActionController::Parameters.new("filter.podcast_id.gte": "1D")
    filter = Compositions::Components::Filter.all_from_params(params).first
    assert_equal 86400, filter.gte
  end

  test "raises when setting nil gte" do
    assert_raises(RuntimeError) do
      @model.gte = nil
    end
  end

  test "raises when setting non-integer gte" do
    assert_raises(RuntimeError) do
      @model.gte = "bogus"
    end
  end

  test "raises when setting nil lt" do
    assert_raises(RuntimeError) do
      @model.gte = nil
    end
  end

  test "raises when setting non-integer lt" do
    assert_raises(RuntimeError) do
      @model.lt = "bogus"
    end
  end

  test "out of order range" do
    @model.gte = 999
    @model.lt = 0
    @model.validate
    assert @model.errors.added?(:gte, :out_of_order)
  end

  test "missing lt" do
    filter = Compositions::Components::Filter.new(:current_episode_age_in_seconds)
    filter.operator = :include
    filter.gte = 999
    filter.validate
    assert filter.errors.added?(:lt, :missing)
    assert filter.errors.added?(:lt, :missing_values)
  end

  test "missing gte" do
    filter = Compositions::Components::Filter.new(:current_episode_age_in_seconds)
    filter.operator = :include
    filter.lt = 999
    filter.validate
    assert filter.errors.added?(:gte, :missing)
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

  test "is invalid with values" do
    @model.values = [1, 2, 3]
    @model.validate
    assert @model.errors.added?(:values, :invalid_option)
  end
end
