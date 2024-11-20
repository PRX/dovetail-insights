require "test_helper"

class RangingTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Compositions::BaseComposition.new
    @model.from = "now/m"
    @model.to = "now/m"
  end

  test "absolute date from" do
    @model.from = "2023-06-21"
    assert_equal DateTime.new(2023, 6, 21, 0, 0, 0, 0), @model.abs_from
  end

  test "absolute time from" do
    @model.from = "2023-06-21T12:34:56Z"
    assert_equal DateTime.new(2023, 6, 21, 12, 34, 56, 0), @model.abs_from
  end

  test "relative from" do
    @model.from = "now/Y"

    travel_to Time.utc(2023, 6, 21, 12, 34, 56) do
      assert_equal DateTime.new(2023, 1, 1, 0, 0, 0, 0), @model.abs_from
    end
  end

  test "absolute date to" do
    @model.to = "2023-06-21"
    assert_equal DateTime.new(2023, 6, 21, 0, 0, 0, 0), @model.abs_to
  end

  test "absolute time to" do
    @model.to = "2023-06-21T12:34:56Z"
    assert_equal DateTime.new(2023, 6, 21, 12, 34, 56, 0), @model.abs_to
  end

  test "valid range order" do
    @model.from = "now-5m"
    @model.to = "now+5m"

    @model.valid?
    assert_not @model.errors.include?(:from)
  end

  test "good absolute date format" do
    @model.from = "2024-01-01"

    @model.valid?
    assert_not @model.errors.include?(:from)
  end

  test "good relative expression" do
    @model.from = "now"

    @model.valid?
    assert_not @model.errors.include?(:from)
  end

  test "relative expression with a space instead of a plus sign" do
    @model.from = "now/Y 5D"

    travel_to Time.utc(2023, 6, 21, 12, 34, 56) do
      assert_equal DateTime.new(2023, 1, 6, 0, 0, 0, 0), @model.abs_from
    end
  end

  test "good absolute time format" do
    @model.from = "2024-01-01T12:34:56Z"

    @model.valid?
    assert_not @model.errors.include?(:from)
  end

  test "raises on non-string from and to" do
    assert_raises { @model.from = nil }
    assert_raises { @model.to = nil }
    assert_raises { @model.from = DateTime.new(2023, 6, 21, 12, 34, 56, 0) }
    assert_raises { @model.to = DateTime.new(2023, 6, 21, 12, 34, 56, 0) }
  end

  test "invalid range order" do
    @model.from = "now+5m"
    @model.to = "now-5m"

    @model.valid?
    assert @model.errors.added?(:from, :out_of_order)
  end

  test "bad absolute date format" do
    @model.from = "2024-99-01"

    @model.valid?
    assert @model.errors.added?(:from, :invalid_date)
  end

  test "bad absolute time format" do
    @model.from = "2024-01-01T12:34:56" # must end with Z

    @model.valid?
    assert @model.errors.added?(:from, :invalid_date)
  end

  test "bad relative expression" do
    @model.from = "now/A"

    @model.valid?
    assert @model.errors.added?(:from, :invalid_expression)
  end
end
