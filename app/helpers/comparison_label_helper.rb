module ComparisonLabelHelper
  def comparison_label(comparison, interval_descriptor, rewind)
    case comparison.period
    when :YoY
      interval_descriptor.advance(years: rewind)
    when :QoQ
      interval_descriptor.advance(months: 3 * rewind)
    when :WoW
      interval_descriptor.advance(weeks: rewind)
    end
  end
end
