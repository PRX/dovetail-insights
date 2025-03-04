module ResultsHelper
  def default_group_member_descriptor_sort(compostion, group, member_descriptors)
    member_descriptors.sort_by do |member_descriptor|
      if group
        dimension_def = DataSchema.dimensions[group.dimension.to_s]

        if dimension_def["SortProperties"].present?
          dimension_def["SortProperties"].map do |sort_property_name|
            @composition.results.group_sort_descriptor(group, member_descriptor, sort_property_name)
          end
        elsif member_descriptor == member_descriptor.to_i.to_s
          # If this descriptor looks like an integer, treat it as an actual
          # integer to get 1,2,10 rather than 1,10,2
          member_descriptor.to_i
        else
          # Otherwise, sort by the final label
          member_label(@composition, group, member_descriptor)
        end
      end
    end.reverse

    # TODO Only reverse if there's a sort property, and even that is not ideal,
    # the schema should be able to indicate sort order
  end
end
