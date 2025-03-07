module GroupMemberLabelHelper
  ##
  # Take a number of seconds and returns a simplified string when the seconds
  # is divisible evenly into years/weeks/etcs. The string includes the
  # resulting units.
  # E.g., 86_400 => "1 day"
  # E.g., 172_800 => "2 days"
  #
  # Any value that isn't evenly divisible remains in seconds.
  # E.g., 1000 => "1,000 seconds"
  #
  # TODO Localize units

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

  ##
  # Given a timestamp string like 2025-01-01T12:34:56Z, removes the time part
  # of the string if it is midnight, returning just the date

  def compact_timestamp_string(time_string)
    time_string.gsub("T00:00:00Z", "")
  end

  ##
  # Takes a group member descriptor, which will be a number, for a duration
  # range and returns a string that describes that range in words.

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

  ##
  # Takes a group member descriptor for an timestamp extraction group, which
  # will be a number (like 1 for Sunday, or 13 for hour, or 2025 for year) and
  # returns a formatted string suitable for displaying to the user

  def timestamp_extract_label(composition, group, member_descriptor)
    case group.extract
    when :month
      Date::ABBR_MONTHNAMES[member_descriptor.to_i]
    when :week
      "Week #{member_descriptor}"
    when :day
      member_descriptor.to_i.ordinalize
    when :day_of_week
      ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][member_descriptor.to_i]
    when :hour
      "#{member_descriptor}:00"
    else
      member_descriptor.to_s
    end
  end

  ##
  # Takes a group member descriptor for a single timestamp range, which will be
  # a timestamp string, and returns a string that describes that range in words

  def timestamp_range_label(composition, group, member_descriptor)
    index_of_index = group.abs_indices.index(member_descriptor)

    if member_descriptor == Compositions::Components::Group::TERMINATOR_INDEX
      "After #{compact_timestamp_string group.abs_indices.last}"
    elsif index_of_index == 0
      "Before #{compact_timestamp_string member_descriptor}"
    else
      "Between #{compact_timestamp_string group.abs_indices[index_of_index - 1]} and #{compact_timestamp_string member_descriptor}"
    end
  end

  ##
  # Takes a group member descriptor for a truncated timestamp, which will be a
  # timestamp string, and returns a reformatted string suitable for displaying
  # to the user

  def timestamp_truncate_label(composition, group, member_descriptor)
    case group.truncate
    when :year
      compact_timestamp_string member_descriptor
    when :month
      compact_timestamp_string member_descriptor
    when :week
      compact_timestamp_string member_descriptor
    end
  end

  ##
  # Handes labels for various types of Timestamp groups, like range, extact
  # and truncate.

  def timestamp_label(composition, group, member_descriptor)
    if group.extract
      timestamp_extract_label(composition, group, member_descriptor)
    elsif group.truncate
      timestamp_truncate_label(composition, group, member_descriptor)
    elsif group.indices
      timestamp_range_label(composition, group, member_descriptor)
    end
  end

  ##
  # For a given group member, this is meant to return the label most appropriate
  # to display to a user for overall ease-of-use.
  #
  # Some dimensions use their member descriptor as the user-facing label. Some
  # define an exhibit property, which is a value from the database that is
  # meant to be used instead of the descriptor. In some situations, the
  # descriptor or exhibitition are further refined or replaced by this helper.
  #
  # Some times refinement happens for an entire class of members, like how all
  # duration descriptors are replaced to be more meaningful and readible. Other
  # time, an individual value may need to be replaced before being displayed to
  # the user, like we may want to override the name of a specific user agent.
  #
  # When member_descriptor is nil, this is being used to label data that is not
  # associated with any member of the group (e.g., downloads that don't have a
  # country, because we didn't determine the origin).
  #
  # Generally the UI will not include elements where group is nil, but for
  # completeness, that case is handled as well

  def member_label(composition, group, member_descriptor)
    return "NO GROUP SELECTED" unless group # TODO
    return "Indeterminate #{prop_or_dim_label(group.dimension)}" unless member_descriptor

    dimension_def = DataSchemaUtil.field_definition(group.dimension)

    exhibition = composition.results.group_member_exhibition(group, member_descriptor)

    if dimension_def["Type"] == "Duration"
      duration_label(composition, group, member_descriptor)
    elsif dimension_def["Type"] == "Timestamp"
      timestamp_label(composition, group, member_descriptor)
    elsif I18n.exists? "group_member_labels.replace_descriptors.#{group.dimension}.#{member_descriptor}"
      # Use the localized version of this descriptor if it exists
      translate "group_member_labels.replace_descriptors.#{group.dimension}.#{member_descriptor}"
    elsif I18n.exists? "group_member_labels.replace_exhibitions.#{group.dimension}.#{exhibition}"
      # Use the localized version of this descriptor's exhibition if it exists
      translate "group_member_labels.replace_exhibitions.#{group.dimension}.#{exhibition}"
    elsif group.dimension == :season_number
      "Season #{member_descriptor}"
    elsif group.dimension == :episode_number
      "Episode #{member_descriptor}"
    else
      exhibition
    end
  end
end
