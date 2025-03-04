module DataExplorerHelper
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
end
