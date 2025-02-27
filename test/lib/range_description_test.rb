# TODO I thought this should be autoloaded
require_relative "../../app/lib/range_description"

class RelatimeTest < ActiveSupport::TestCase
  test "previous X units" do
    desc = RangeDescription.in_words("now-1/h", "now-1/h")
    assert_equal "the previous hour", desc

    desc = RangeDescription.in_words("now-1/M", "now-1/M")
    assert_equal "the previous month", desc

    desc = RangeDescription.in_words("now-6/M", "now-1/M")
    assert_equal "the previous 6 months", desc

    desc = RangeDescription.in_words("now-1/Y", "now-1/Y")
    assert_equal "the previous year", desc

    desc = RangeDescription.in_words("now-6/Y", "now-1/Y")
    assert_equal "the previous 6 years", desc
  end

  test "this unit" do
    desc = RangeDescription.in_words("now/h", "now/h")
    assert_equal "this hour", desc

    desc = RangeDescription.in_words("now/M", "now/M")
    assert_equal "this month", desc

    desc = RangeDescription.in_words("now/Y", "now/Y")
    assert_equal "this year", desc
  end

  test "this unit so far" do
    desc = RangeDescription.in_words("now/M", "now")
    assert_equal "this month so far", desc

    desc = RangeDescription.in_words("now/Y", "now")
    assert_equal "this year so far", desc
  end

  test "units ago to now" do
    desc = RangeDescription.in_words("now-48h", "now")
    assert_equal "48 hours ago to now", desc

    desc = RangeDescription.in_words("now-3M", "now")
    assert_equal "3 months ago to now", desc
  end

  test "complete year" do
    desc = RangeDescription.in_words("2024-01-01T00:00:00Z", "2025-01-01T00:00:00Z")
    assert_equal "2024", desc
  end

  test "complete years" do
    desc = RangeDescription.in_words("2023-01-01T00:00:00Z", "2025-01-01T00:00:00Z")
    assert_equal "2023–2024", desc
  end

  test "complete month" do
    desc = RangeDescription.in_words("2024-01-01T00:00:00Z", "2024-02-01T00:00:00Z")
    assert_equal "Jan 2024", desc
  end

  test "complete months" do
    desc = RangeDescription.in_words("2024-01-01T00:00:00Z", "2024-03-01T00:00:00Z")
    assert_equal "Jan 2024—Feb 2024", desc

    desc = RangeDescription.in_words("2023-05-01T00:00:00Z", "2024-03-01T00:00:00Z")
    assert_equal "May 2023—Feb 2024", desc
  end
end
