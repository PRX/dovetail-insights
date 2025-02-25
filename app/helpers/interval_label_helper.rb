module IntervalLabelHelper
  ##
  # Takes a granularity descriptor and returns a formatted string
  # representation suitable for displaying within the results.
  #
  # For example, the descriptor may be a string like "2023-01-01T12:34:56T"
  # but the results are intended to only display the year, like if the user
  # selected _yearly_ grouping. This will return +"2023"+, based on that chosen
  # granularity.

  def interval_label(composition, interval_descriptor)
    # Parse the given descriptor into a Time
    time = Time.parse(interval_descriptor)

    # Compose an appropriately formatted string based on the chosen granularity
    case composition.granularity
    when :daily
      time.strftime("%F")
    when :weekly
      "Week of #{time.strftime("%F")}"
    when :monthly
      time.strftime("%Y-%m")
    when :quarterly
      y = time.strftime("%Y")
      m = time.strftime("%-m")
      q = (m.to_f / 3).ceil
      "#{y}Q#{q}"
    when :yearly
      time.strftime("%Y")
    when :rolling
      "#{human_duration composition.window} starting #{compact_timestamp_string interval_descriptor}"
    else
      interval_descriptor
    end
  end
end
