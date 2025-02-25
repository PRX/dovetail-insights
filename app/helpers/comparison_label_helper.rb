module ComparisonLabelHelper
  def comparison_descriptor(comparison, interval_descriptor, rewind)
    # Parse the given descriptor into a Time
    time = Time.parse(interval_descriptor)

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
