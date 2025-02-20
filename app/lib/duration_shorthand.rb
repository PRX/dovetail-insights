##
# Takes a string like "10D" or "12h" and expands it into the total number of
# seconds represented by that duration. Expects the number part to be a
# positive natural number. Returns an +Integer+.
#
# Supports:
# Y = year
# W = week
# D = day
# h = hour
# m = minute
#
# Does not deal with things like leap years.
#
# This intentionally does not support _months_ because it's ambiguous.

class DurationShorthand
  def self.expand(value)
    if /^[0-9]+[YWDhm]$/.match?(value)
      if value.include?("Y")
        value.to_i * 86400 * 365
      elsif value.include?("W")
        value.to_i * 86400 * 7
      elsif value.include?("D")
        value.to_i * 86400
      elsif value.include?("h")
        value.to_i * 3600
      elsif value.include?("m")
        value.to_i * 60
      end
    elsif /^[0-9]+$/.match?(value)
      value.to_i
    else
      value
    end
  end
end
