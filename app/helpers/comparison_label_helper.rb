module ComparisonLabelHelper
  ##
  # Generates a descriptor for a specific comparison interval, based on a
  # non-comparison interval (i.e., some interval from the base query) and a
  # rewind value.
  #
  # For example, if given 2024-01-01T:00:00:00, and a YoY rewind of -2, this
  # would return 2022-01-01T:00:00:00

  def comparison_descriptor(comparison, interval_descriptor, rewind)
    # Parse the given descriptor into a Time
    time = Time.parse(interval_descriptor).utc

    # Create a descriptor for the rewind value, based on the interval
    # descriptor. These will match descriptors in comparison query results.
    case comparison.period
    when :YoY
      time.advance(years: rewind).strftime("%Y-%m-%dT%H:%M:%SZ")
    when :QoQ
      time.advance(months: 3 * rewind).strftime("%Y-%m-%dT%H:%M:%SZ")
    when :WoW
      time.advance(weeks: rewind).strftime("%Y-%m-%dT%H:%M:%SZ")
    end
  end
end
