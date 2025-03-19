module ResultsHelper
  ##
  # Given a group and a set of member descriptors from the results, returns all
  # those descriptors sorted in the most appropriate way for a default display
  # to the user.
  #
  # This factors in things like sort properties, labels, and other things that
  # may change the order compared to the raw descriptors.
  #
  # The values returned by the +sort_by+ block are arrays, where the first
  # element is some integer used to sort classes of values. Any number of other
  # elements can follow, but +sort_by+ generally expects them to all be the
  # same type (or at least comparable).

  def default_group_member_descriptor_sort(compostion, group, member_descriptors)
    member_descriptors.sort_by do |member_descriptor|
      if group
        dimension_def = DataSchemaUtil.field_definition(group.dimension)

        if !member_descriptor
          # Force null groups to the bottom
          [99]
        elsif dimension_def["SortFields"].present?
          # If the dimension has sort fields, always sort by the raw sort field
          # values, in the order the fields are listed in the schema
          #
          # Note that once the descriptor is converted to a label, that label
          # value may appear out of place

          [10, *dimension_def["SortFields"].map do |sort_field_name|
            d = @composition.results.group_sort_descriptor(group, member_descriptor, sort_field_name)

            # If the value appears to be a number, sort it numerically
            (d.to_s == d.to_i.to_s) ? d.to_i : d.downcase
          end]
        elsif group.extract
          # Timestamps using extraction should be sorted by the raw descriptor,
          # which will always be a number, and should be sorted numerically
          [20, member_descriptor.to_i]
        elsif group.indices
          # For ranges, sort numerically by raw descriptor, but force the final
          # range to the bottom
          (member_descriptor == Compositions::Components::Group::TERMINATOR_INDEX) ? [21, member_descriptor] : [20, member_descriptor.to_i]
        else
          # Othewise sort lexicographically by the final display label
          [50, member_label(@composition, group, member_descriptor).downcase]
        end
      end
    end
  end

  ##
  # Build a <th> tag for the given descriptor. +skip_content+ can be used to
  # produce an empty tag.

  def group_table_header_tag(composition, group, member_descriptor, th_scope, skip_content = false)
    group_num = composition.groups&.index(group)&.+ 1

    # TODO This is a hack
    @default_sort_index ||= {}
    @default_sort_index[th_scope] ||= 0

    dimension_def = DataSchemaUtil.field_definition(group&.dimension)

    sort_values = if dimension_def&.[]("SortFields").present?
      dimension_def["SortFields"].map { |field_name| composition.results.group_sort_descriptor(group, member_descriptor, field_name) }
    else
      [member_descriptor || "__nil__"]
    end

    opts = {
      colspan: (th_scope == :colgroup) ? composition.metrics&.size : 1,
      scope: th_scope,
      data: {
        "dx-group-#{group_num}-dimension-name": group&.dimension,
        "dx-group-#{group_num}-member-descriptor": member_descriptor || "__nil__",
        "dx-group-#{group_num}-member-sort-values": sort_values.join(","),
        "dx-group-#{group_num}-default-sort-index": @default_sort_index[th_scope]
      }
    }

    @default_sort_index[th_scope] += 1

    content_tag(:th, opts) do
      member_label(composition, group, member_descriptor) unless skip_content
    end
  end

  ##
  # Returns a value suitable for displaying to the user for the input. This may
  # include formatting/overriding/etc, but it does **not** use the exhibit
  # field for the associated meta field.
  #
  # For example, if the input value is an episode UUID coming from the
  # `episode_id` field, this would not replace that value with the episode's
  # name. The intention of this method is to display the raw value.

  def meta_descriptor_label(group, meta_value)
    meta_value
  end
end
