module GroupMemberLabelHelper
  def human_duration(seconds)
    if seconds % (86400 * 365) == 0
      years = seconds / (86400 * 365)
      "#{years.to_i} #{"year".pluralize(years)}"
    elsif seconds % (86400 * 7) == 0 && seconds > (86400 * 28)
      weeks = seconds / (86400 * 7)
      "#{weeks.to_i} #{"week".pluralize(weeks)}"
    elsif seconds % 86400 == 0
      days = seconds / 86400
      "#{days.to_i} #{"day".pluralize(days)}"
    else
      "#{ActionController::Base.helpers.number_with_delimiter seconds.to_i} #{"second".pluralize(seconds)}"
    end
  end

  def duration_label(composition, group, member_descriptor)
    index_of_index = group.indices.index(member_descriptor.to_i)

    if member_descriptor == Compositions::Components::Group::TERMINATOR_INDEX
      "Over #{human_duration(group.indices.last)}"
    elsif index_of_index == 0
      "Under #{human_duration(member_descriptor.to_f)}"
    else
      "Between #{human_duration(group.indices[index_of_index - 1])} and #{human_duration(member_descriptor.to_f)}"
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
