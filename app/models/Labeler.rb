##
# A utility class that transforms a raw label (some value that was returned as
# part of a query result) into a more human-friendly equivalent (if necessary).

class Labeler
  def self.label(input, group)
    dimension_def = DataSchema.dimensions[group.dimension.to_s]

    if dimension_def["Type"] == "Timestamp"
      case group.extract
      when "month"
        return Date::ABBR_MONTHNAMES[input.to_i]
      when "week"
        return "Week #{input}"
      when "day"
        return input.to_i.ordinalize
      when "dayofweek"
        return ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][input.to_i]
      when "hour"
        return "#{input}:00"
      end
    elsif dimension_def["Type"] == "Duration"
      if input.starts_with? "LT"
        val = input.sub("LT ", "").to_f

        if val % (86400 * 365) == 0
          val /= (86400 * 365)
          return "Under #{val.to_i} #{"year".pluralize(val)}"
        elsif val % (86400 * 7) == 0 && val > (86400 * 28)
          val /= (86400 * 7)
          return "Under #{val.to_i} #{"week".pluralize(val)}"
        elsif val % 86400 == 0
          val /= 86400
          return "Under #{val.to_i} #{"day".pluralize(val)}"
        else
          return "Under #{ActionController::Base.helpers.number_with_delimiter val.to_i} #{"second".pluralize(val)}"
        end
      else
        val = input.sub("GTE ", "").to_f

        if val % (86400 * 365) == 0
          val /= (86400 * 365)
          return "#{val.to_i} #{"year".pluralize(val)} or more"
        elsif val % (86400 * 7) == 0 && val > (86400 * 28)
          val /= (86400 * 7)
          return "#{val.to_i} #{"week".pluralize(val)} or more"
        elsif val % 86400 == 0
          val /= 86400
          return "#{val.to_i} #{"day".pluralize(val)} or more"
        else
          return "#{ActionController::Base.helpers.number_with_delimiter val} #{"second".pluralize(val)} or more"
        end
      end
    end

    input
  end
end
