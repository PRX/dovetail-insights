module ComparisonLabelHelper
  def comparison_label(comparison, granularity_member_descriptor, rewind)
    case comparison.period
    when :YoY
      granularity_member_descriptor.advance(years: rewind)
    when :QoQ
      granularity_member_descriptor.advance(months: 3 * rewind)
    when :WoW
      granularity_member_descriptor.advance(weeks: rewind)
    end
  end
end
