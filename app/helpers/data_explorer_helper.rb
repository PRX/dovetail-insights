module DataExplorerHelper
  ##
  # Takes a member, which is something like a +Time+ or +DateTime+, and returns
  # a formatted string representation suitable for displaying within the
  # results.
  #
  # For example, the results may contain a +DateTime+ like +2023-01-01 00:00:00+
  # but the results are intended to only display the year, like if the user
  # selected _yearly_ grouping. This will return +"2023"+, based on that chosen
  # granularity.

  def granularity_label(composition, member)
    case composition.granularity
    when :daily
      member.strftime("%F")
    when :weekly
      "W #{member.strftime("%F")}"
    when :monthly
      member.strftime("%Y-%m")
    when :quarterly
      y = member.strftime("%Y")
      m = member.strftime("%-m")
      q = (m.to_f / 3).ceil
      "#{y}Q#{q}"
    when :yearly
      member.strftime("%Y")
    else
      member
    end
  end
end
