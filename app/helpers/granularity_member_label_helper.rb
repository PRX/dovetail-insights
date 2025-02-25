module GranularityMemberLabelHelper
  ##
  # Takes a member, which is something like a +Time+ or +DateTime+, and returns
  # a formatted string representation suitable for displaying within the
  # results.
  #
  # For example, the results may contain a +DateTime+ like +2023-01-01 00:00:00+
  # but the results are intended to only display the year, like if the user
  # selected _yearly_ grouping. This will return +"2023"+, based on that chosen
  # granularity.

  def granularity_label(composition, member_descriptor)
    case composition.granularity
    when :daily
      member_descriptor.strftime("%F")
    when :weekly
      "Week of #{member_descriptor.strftime("%F")}"
    when :monthly
      member_descriptor.strftime("%Y-%m")
    when :quarterly
      y = member_descriptor.strftime("%Y")
      m = member_descriptor.strftime("%-m")
      q = (m.to_f / 3).ceil
      "#{y}Q#{q}"
    when :yearly
      member_descriptor.strftime("%Y")
    when :rolling
      "#{human_duration composition.window} starting #{clean_timestamp_string member_descriptor}"
    else
      member_descriptor
    end
  end
end
