# TODO I thought this should be autoloaded
require_relative "../../app/lib/relatime"

class RelatimeTest < ActiveSupport::TestCase
  setup do
    @now = Time.utc(2023, 6, 21, 10, 11, 12)
  end

  test "now" do
    travel_to @now do
      assert_equal DateTime.new(2023, 6, 21, 10, 11, 12, 0), Relatime.rel2abs("now", :front)
      assert_equal DateTime.new(2023, 6, 21, 10, 11, 12, 0), Relatime.rel2abs("now", :back)
    end
  end

  test "snapping to time boundaries, range start" do
    travel_to @now do
      assert_equal DateTime.new(2023, 1, 1, 0, 0, 0, 0), Relatime.rel2abs("now/Y", :front)
      assert_equal DateTime.new(2023, 4, 1, 0, 0, 0, 0), Relatime.rel2abs("now/Q", :front)
      assert_equal DateTime.new(2023, 6, 1, 0, 0, 0, 0), Relatime.rel2abs("now/M", :front)
      assert_equal DateTime.new(2023, 6, 18, 0, 0, 0, 0), Relatime.rel2abs("now/W", :front)
      assert_equal DateTime.new(2023, 6, 19, 0, 0, 0, 0), Relatime.rel2abs("now/X", :front)
      assert_equal DateTime.new(2023, 6, 21, 0, 0, 0, 0), Relatime.rel2abs("now/D", :front)
      assert_equal DateTime.new(2023, 6, 21, 10, 0, 0, 0), Relatime.rel2abs("now/h", :front)
      assert_equal DateTime.new(2023, 6, 21, 10, 11, 0, 0), Relatime.rel2abs("now/m", :front)
    end
  end

  test "snapping to time boundaries, range end" do
    travel_to @now do
      assert_equal DateTime.new(2024, 1, 1, 0, 0, 0, 0), Relatime.rel2abs("now/Y", :back)
      assert_equal DateTime.new(2023, 7, 1, 0, 0, 0, 0), Relatime.rel2abs("now/Q", :back)
      assert_equal DateTime.new(2023, 7, 1, 0, 0, 0, 0), Relatime.rel2abs("now/M", :back)
      assert_equal DateTime.new(2023, 6, 25, 0, 0, 0, 0), Relatime.rel2abs("now/W", :back)
      assert_equal DateTime.new(2023, 6, 26, 0, 0, 0, 0), Relatime.rel2abs("now/X", :back)
      assert_equal DateTime.new(2023, 6, 22, 0, 0, 0, 0), Relatime.rel2abs("now/D", :back)
      assert_equal DateTime.new(2023, 6, 21, 11, 0, 0, 0), Relatime.rel2abs("now/h", :back)
      assert_equal DateTime.new(2023, 6, 21, 10, 12, 0, 0), Relatime.rel2abs("now/m", :back)
    end
  end

  test "shift back 5 minutes" do
    travel_to @now do
      assert_equal DateTime.new(2023, 6, 21, 10, 6, 12, 0), Relatime.rel2abs("now-5m", :front)
      assert_equal DateTime.new(2023, 6, 21, 10, 6, 12, 0), Relatime.rel2abs("now-5m", :back)
    end
  end

  test "shift back 1 day" do
    travel_to @now do
      assert_equal DateTime.new(2023, 6, 20, 10, 11, 12, 0), Relatime.rel2abs("now-1D", :front)
      assert_equal DateTime.new(2023, 6, 20, 10, 11, 12, 0), Relatime.rel2abs("now-1D", :back)
    end
  end

  test "shift back 23 days, into the previous month" do
    travel_to @now do
      assert_equal DateTime.new(2023, 5, 29, 10, 11, 12, 0), Relatime.rel2abs("now-23D", :front)
      assert_equal DateTime.new(2023, 5, 29, 10, 11, 12, 0), Relatime.rel2abs("now-23D", :back)
    end
  end

  test "shift forward 12 days, into the next month" do
    travel_to @now do
      assert_equal DateTime.new(2023, 7, 3, 10, 11, 12, 0), Relatime.rel2abs("now+12D", :front)
      assert_equal DateTime.new(2023, 7, 3, 10, 11, 12, 0), Relatime.rel2abs("now+12D", :back)
    end
  end

  test "snap to offset time boundary" do
    travel_to @now do
      assert_equal DateTime.new(2022, 1, 1, 0, 0, 0, 0), Relatime.rel2abs("now-1/Y", :front)
      assert_equal DateTime.new(2022, 1, 1, 0, 0, 0, 0), Relatime.rel2abs("now-1Y/Y", :front)
      assert_equal DateTime.new(2023, 1, 1, 0, 0, 0, 0), Relatime.rel2abs("now-1/Y", :back)
      assert_equal DateTime.new(2023, 1, 1, 0, 0, 0, 0), Relatime.rel2abs("now-1Y/Y", :back)
    end
  end

  test "entire current calendar month" do
    travel_to @now do
      assert_equal DateTime.new(2023, 6, 1, 0, 0, 0, 0), Relatime.rel2abs("now/M", :front)
      assert_equal DateTime.new(2023, 7, 1, 0, 0, 0, 0), Relatime.rel2abs("now/M", :back)
    end
  end

  test "current calendar month so far" do
    travel_to @now do
      assert_equal DateTime.new(2023, 6, 1, 0, 0, 0, 0), Relatime.rel2abs("now/M", :front)
      assert_equal DateTime.new(2023, 6, 21, 10, 11, 12, 0), Relatime.rel2abs("now", :back)
    end
  end

  test "current calendar year so far" do
    travel_to @now do
      assert_equal DateTime.new(2023, 1, 1, 0, 0, 0, 0), Relatime.rel2abs("now/Y", :front)
      assert_equal DateTime.new(2023, 6, 21, 10, 11, 12, 0), Relatime.rel2abs("now", :back)
    end
  end

  test "last 30 minutes" do
    travel_to @now do
      assert_equal DateTime.new(2023, 6, 21, 9, 41, 12, 0), Relatime.rel2abs("now-30m", :front)
      assert_equal DateTime.new(2023, 6, 21, 10, 11, 12, 0), Relatime.rel2abs("now", :back)
    end
  end

  test "previous full calendar month so far" do
    travel_to @now do
      assert_equal DateTime.new(2023, 5, 1, 0, 0, 0, 0), Relatime.rel2abs("now-1/M", :front)
      assert_equal DateTime.new(2023, 6, 1, 0, 0, 0, 0), Relatime.rel2abs("now-1/M", :back)
    end
  end

  test "Monday through Friday of the previous week, where weeks start on Monday" do
    travel_to @now do
      assert_equal DateTime.new(2023, 6, 12, 0, 0, 0, 0), Relatime.rel2abs("now-1/X", :front)
      assert_equal DateTime.new(2023, 6, 17, 0, 0, 0, 0), Relatime.rel2abs("now-1/X-2D", :back)
    end
  end

  test "Monday through Friday of the previous week, where weeks start on Sunday" do
    travel_to @now do
      assert_equal DateTime.new(2023, 6, 12, 0, 0, 0, 0), Relatime.rel2abs("now-1/W+1D", :front)
      assert_equal DateTime.new(2023, 6, 17, 0, 0, 0, 0), Relatime.rel2abs("now-1/W-1D", :back)
    end
  end

  test "start of week, where weeks start on a monday, when it's currently monday" do
    travel_to Time.utc(2023, 6, 19, 10, 11, 12) do
      assert_equal DateTime.new(2023, 6, 19, 0, 0, 0, 0), Relatime.rel2abs("now/X", :front)
      assert_equal DateTime.new(2023, 6, 26, 0, 0, 0, 0), Relatime.rel2abs("now/X", :back)
    end
  end

  test "start of week, where weeks start on a monday, when it's currently sunday" do
    travel_to Time.utc(2023, 6, 25, 10, 11, 12) do
      assert_equal DateTime.new(2023, 6, 19, 0, 0, 0, 0), Relatime.rel2abs("now/X", :front)
      assert_equal DateTime.new(2023, 6, 26, 0, 0, 0, 0), Relatime.rel2abs("now/X", :back)
    end
  end

  test "start of week, where weeks start on a sunday, when it's currently monday" do
    travel_to Time.utc(2023, 6, 19, 10, 11, 12) do
      assert_equal DateTime.new(2023, 6, 18, 0, 0, 0, 0), Relatime.rel2abs("now/W", :front)
      assert_equal DateTime.new(2023, 6, 25, 0, 0, 0, 0), Relatime.rel2abs("now/W", :back)
    end
  end

  test "start of week, where weeks start on a sunday, when it's currently sunday" do
    travel_to Time.utc(2023, 6, 18, 10, 11, 12) do
      assert_equal DateTime.new(2023, 6, 18, 0, 0, 0, 0), Relatime.rel2abs("now/W", :front)
      assert_equal DateTime.new(2023, 6, 25, 0, 0, 0, 0), Relatime.rel2abs("now/W", :back)
    end
  end

  test "The 5th through the 15th of the previous month" do
    travel_to @now do
      assert_equal DateTime.new(2023, 5, 5, 0, 0, 0, 0), Relatime.rel2abs("now-1/M+4D", :front)
      assert_equal DateTime.new(2023, 5, 16, 0, 0, 0, 0), Relatime.rel2abs("now-2/M+15D", :back)
    end
  end

  test "The 5th through the 15th of the previous month, starting and ending at noon" do
    travel_to @now do
      assert_equal DateTime.new(2023, 5, 5, 12, 0, 0, 0), Relatime.rel2abs("now-1/M+4D+12h", :front)
      assert_equal DateTime.new(2023, 5, 16, 12, 0, 0, 0), Relatime.rel2abs("now-2/M+15D+12h", :back)
    end
  end

  test "The previous 50 hours, not including the current hour (50 total hours)" do
    travel_to @now do
      assert_equal DateTime.new(2023, 6, 19, 8, 0, 0, 0), Relatime.rel2abs("now-50/h", :front)
      assert_equal DateTime.new(2023, 6, 21, 10, 0, 0, 0), Relatime.rel2abs("now-1/h", :back)
    end
  end

  test "The previous 50 hours and the current hour (50 total hours)" do
    travel_to @now do
      assert_equal DateTime.new(2023, 6, 19, 9, 0, 0, 0), Relatime.rel2abs("now-49/h", :front)
      assert_equal DateTime.new(2023, 6, 21, 11, 0, 0, 0), Relatime.rel2abs("now/h", :back)
    end
  end

  test "The previous 3 quaters" do
    travel_to @now do
      assert_equal DateTime.new(2022, 7, 1, 0, 0, 0, 0), Relatime.rel2abs("now-3/Q", :front)
      assert_equal DateTime.new(2023, 4, 1, 0, 0, 0, 0), Relatime.rel2abs("now-1/Q", :back)
    end
  end

  test "shift ordering" do
    travel_to @now do
      assert_equal DateTime.new(2023, 1, 28, 12, 0, 0, 0), Relatime.rel2abs("now/Y+2M-12h-1M", :front)
      assert_equal DateTime.new(2023, 1, 31, 12, 0, 0, 0), Relatime.rel2abs("now/Y+2M-1M-12h", :front)
    end
  end

  test "shift clamping" do
    travel_to Time.utc(2023, 3, 31, 0, 0, 0) do
      assert_equal DateTime.new(2023, 2, 28, 0, 0, 0, 0), Relatime.rel2abs("now-1M", :front)
      assert_equal DateTime.new(2023, 1, 28, 0, 0, 0, 0), Relatime.rel2abs("now-1M-1M", :front)
      assert_equal DateTime.new(2023, 1, 31, 0, 0, 0, 0), Relatime.rel2abs("now-2M", :front)
    end
  end

  test "raise on invalid expression" do
    assert_raises(RelativeExpressionError) do
      assert_equal DateTime.new(2023, 1, 28, 12, 0, 0, 0), Relatime.rel2abs("now/⛄️", :front)
      assert_equal DateTime.new(2023, 1, 28, 12, 0, 0, 0), Relatime.rel2abs("now", :front)
    end
  end

  test "explicit now" do
    now = DateTime.new(2001, 2, 3, 4, 5, 6)
    assert_equal DateTime.new(2001, 1, 1, 0, 0, 0), Relatime.rel2abs("now/Y", :front, now)
    assert_equal DateTime.new(2002, 1, 1, 0, 0, 0), Relatime.rel2abs("now/Y", :back, now)
  end
end
