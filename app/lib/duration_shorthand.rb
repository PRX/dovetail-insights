##
# TODO Docs
# This intentionally does not support _months_ because of the ambiguity that
# introduces

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
