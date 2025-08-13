module DataExplorerHelper
  ##
  # Takes a +value+, which is expected to be a number representing a number of
  # seconds. If the value is the number of seconds in some whole number common
  # unit of time, like 1 year or 10 years, returns a shorthand string for that
  # value.
  #
  # This always returns a string.
  #
  # For example, if the +value+ is +86400+, which is 1 day, this would return
  # +1D+. If the +value+ is +2_419_200+ (28 days), it returns +28D+.
  #
  # Supports: years, weeks, days, hours, minutes

  def to_duration_shorthand(value)
    return nil if value.blank?

    if value == 0
      0.to_s
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
      value.to_s
    end
  end

  def time_range_preset_item(rel_from, rel_to, label, now)
    abs_from_str = Relatime.rel2abs(rel_from, :front, now).strftime("%Y-%m-%dT%H:%M:%SZ")
    abs_to_str = Relatime.rel2abs(rel_to, :back, now).strftime("%Y-%m-%dT%H:%M:%SZ")

    tag.li do
      tag.div(class: "relative-preset", data: {"dx-range-from" => rel_from, "dx-range-to" => rel_to, "action" => "click->foo#loadPreset"}) do
        label
      end +
        tag.div(class: "absolute-preset material-icons", data: {"bs-toggle" => "tooltip", "bs-custom-class" => "time-range-chooser-toolip", "bs-placement" => "bottom", "bs-delay" => '{"show":333,"hide":0}', "bs-title" => "Use static dates", "dx-range-from" => abs_from_str, "dx-range-to" => abs_to_str, "action" => "click->foo#loadPreset"}) do
          "date_range"
        end
    end
  end
end
