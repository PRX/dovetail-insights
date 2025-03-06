module ResultsHelper
  ##
  # Given a group and a set of member descriptors from the results, returns all
  # those descriptors sorted in the most appropriate way for a default display
  # to the user.
  #
  # This factors in things like sort properties, labels, and other things that
  # may change the order compared to the raw descriptors.

  def default_group_member_descriptor_sort(compostion, group, member_descriptors)
    member_descriptors.sort_by do |member_descriptor|
      if group
        dimension_def = DataSchemaUtil.field_definition(group.dimension)

        # Return an array that sort_by will use for sorting. The first element
        # is always explicitly controlled within this method, other values
        # should follow that.
        if !member_descriptor
          # Force null groups to the bottom
          ["9".rjust(30, "9")]
        elsif dimension_def["SortFields"].present?
          ["0", *dimension_def["SortFields"].map do |sort_property_name|
            @composition.results.group_sort_descriptor(group, member_descriptor, sort_property_name).to_s.rjust(30, "9")
          end]
        elsif member_descriptor == member_descriptor.to_i.to_s
          # If this descriptor looks like an integer, treat it as an actual
          # integer to get 1,2,10 rather than 1,10,2
          ["0", member_descriptor.to_s.rjust(30, "0")]
        else
          # Otherwise, sort by the final label
          ["0", member_label(@composition, group, member_descriptor).rjust(30, "0")]
        end
      end
    end

    # TODO Only reverse if there's a sort property, and even that is not ideal,
    # the schema should be able to indicate sort order
  end

  ##
  # Build a <th> tag for the given descriptor. +skip_content+ can be used to
  # produce an empty tag.

  def group_table_header_tag(composition, group, member_descriptor, th_scope, skip_content = false)
    opts = {
      colspan: (th_scope == :colgroup) ? composition.metrics&.size : 1,
      scope: th_scope,
      data: {
        action: "click->data-explorer--results-table-sort#sort",
        "sort-group-dimension": group&.dimension,
        "sort-group-2-member-descriptor": member_descriptor || "__nil__", # TODO
        "sort-metric": (composition.metrics&.size == 1) ? composition.metrics[0].metric : nil
      }
    }

    content_tag(:th, opts) do
      member_label(composition, group, member_descriptor) unless skip_content || !group
    end
  end

  ##
  # Returns a value suitable for displaying to the user for the input. This may
  # include formatting/overriding/etc, but it does **not** use the exhibit
  # field for the associated meta field.
  #
  # For example, if the input value is an episode UUID coming from the
  # `episode_id` field, this would not replace that value with the episode's
  # name. The point of this is to display the raw value.

  def meta_descriptor_label(group, meta_value)
    meta_value
  end
end
