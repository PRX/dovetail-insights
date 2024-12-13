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

        if val % 86400 == 0
          val = val / 86400
          return "Under #{val.to_i} days"
        else
          return "Under #{number_with_delimiter val} seconds"
        end
      else
        val = input.sub("GTE ", "").to_f

        if val % 86400 == 0
          val = val / 86400
          return "#{val.to_i} days or more"
        else
          return "#{number_with_delimiter val} seconds or more"
        end
      end
    end

    return input
  end
end
