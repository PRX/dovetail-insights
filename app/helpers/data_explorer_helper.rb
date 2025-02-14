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

  ##
  # Takes a +value+, which is expected to be a number representing a number of
  # seconds. If the value is the number of seconds in some whole number common
  # unit of time, like 1 year or 10 years, returns a shorthand string for that
  # value.
  #
  # For example, if the +value+ is +86400+, which is 1 day, this would return
  # +1D+. If the +value+ is +2_419_200+ (28 days), it returns +28D+.
  #
  # Supports: years, weeks, days, hours, minutes

  def to_duration_shorthand(value)
    return nil unless value.present?

    if value == 0
      0
    elsif value % (86400 * 365) == 0
      "#{value / (86400 * 365)}Y"
    elsif value % (86400 * 7) == 0 && value > 86400 * 28
      "#{value / (86400 * 7)}W"
    elsif value % 86400 == 0
      "#{value / 86400}D"
    elsif value % 3600 == 0
      "#{value / 3600}h"
    elsif value % 60 == 0
      "#{value / 60}m"
    else
      value
    end
  end

  ##
  # Converts a value from Compositions::Components::EXTRACT_OPTS to the
  # matching argument used by BigQuery EXTRACT()

  def bigquery_extract_argument(opt)
    {
      hour: "HOUR",
      day_of_week: "DAYOFWEEK",
      day: "DAY",
      week: "WEEK",
      month: "MONTH",
      year: "YEAR"
    }[opt]
  end

  ##
  # Converts a value from Compositions::Components::TRUNCATE_OPTS to the
  # matching argument used by BigQuery TIMESTAMP_TRUNC()

  def bigquery_truncate_argument(opt)
    {
      week: "WEEK",
      month: "MONTH",
      year: "YEAR"
    }[opt]
  end
end
