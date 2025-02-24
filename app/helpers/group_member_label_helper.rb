module GroupMemberLabelHelper
  def duration_label(composition, group, member_descriptor)
    if member_descriptor == Compositions::Components::Group::TERMINATOR_INDEX
      "Over"
      # if member_descriptor.starts_with? "LT"
      #   val = member_descriptor.sub("LT ", "").to_f

      # else
      #   val = member_descriptor.sub("GTE ", "").to_f

      #   if val % (86400 * 365) == 0
      #     val /= (86400 * 365)
      #     return "#{val.to_i} #{"year".pluralize(val)} or more"
      #   elsif val % (86400 * 7) == 0 && val > (86400 * 28)
      #     val /= (86400 * 7)
      #     return "#{val.to_i} #{"week".pluralize(val)} or more"
      #   elsif val % 86400 == 0
      #     val /= 86400
      #     return "#{val.to_i} #{"day".pluralize(val)} or more"
      #   else
      #     return "#{ActionController::Base.helpers.number_with_delimiter val} #{"second".pluralize(val)} or more"
      #   end
      # end
    else
      val = member_descriptor.to_f

      if val % (86400 * 365) == 0
        val /= (86400 * 365)
        "Under #{val.to_i} #{"year".pluralize(val)}"
      elsif val % (86400 * 7) == 0 && val > (86400 * 28)
        val /= (86400 * 7)
        "Under #{val.to_i} #{"week".pluralize(val)}"
      elsif val % 86400 == 0
        val /= 86400
        "Under #{val.to_i} #{"day".pluralize(val)}"
      else
        "Under #{ActionController::Base.helpers.number_with_delimiter val.to_i} #{"second".pluralize(val)}"
      end
    end
  end

  def member_label(composition, group, member_descriptor)
    return "UNKNOWN" unless member_descriptor

    dimension_def = DataSchema.dimensions[group.dimension.to_s]

    if dimension_def["Type"] == "Duration"
      return duration_label(composition, group, member_descriptor)
    end

    if dimension_def["Type"] == "Timestamp"
      if group.extract
        case group.extract
        when :month
          return Date::ABBR_MONTHNAMES[member_descriptor.to_i]
        when :week
          return "Week #{member_descriptor}"
        when :day
          return member_descriptor.to_i.ordinalize
        when :day_of_week
          return ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][member_descriptor.to_i]
        when :hour
          return "#{member_descriptor}:00"
        end
      elsif group.indices
        if member_descriptor.starts_with? "LT"
          return member_descriptor.sub("LT", "Before")
        elsif member_descriptor.starts_with? "GTE"
          return member_descriptor.sub("GTE", "After")
        end
      end
    end

    composition.results.group_member_exhibition(group, member_descriptor)
  end
end
