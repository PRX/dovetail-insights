##
# Utilities for any +Results+ classes that deal with groups.

module GroupableResults
  extend ActiveSupport::Concern

  included do
    ##
    # Returns an array of all unique member descriptors for this group in the
    # given results. For dimensions whose selector is something like an ID,
    # these descriptors will be like [1,2,3]. When the selector is not an ID,
    # e.g., time zone, this would be like ["America/New York",
    # "Europe/London"].

    def unique_group_member_descriptors(group)
      return unless group

      # If the group has indices, we want to maintain the order of the
      # indices as they were defined
      if group.indices
        members = group.abs_indices.map { |i| i.to_s }
        members.push(Compositions::Components::Group::TERMINATOR_INDEX)
      else
        rows
          .pluck(group.as)
          .compact
          .uniq
      end
    end

    def group_1_unique_member_descriptors
      @group_1_unique_member_descriptors ||= unique_group_member_descriptors(composition.groups[0])
    end

    def group_2_unique_member_descriptors
      @group_2_unique_member_descriptors ||= unique_group_member_descriptors(composition.groups[1])
    end

    ##
    # Looks up a descriptor for a specific property, based on the descriptor
    # of the group's actual dimension.
    #
    # For example, with a group where dimension=podcast_id, when given
    # 123 and podcast_name, this will return the podcast name for the podcast
    # with ID=123.
    #
    # Can be used for things like ExhibitField, SortFields, meta
    # properties, etc, using the fingerprint to differentiate.

    def group_member_descriptor_for_field(group, member_descriptor, field_name, fingerprint)
      @group_member_descriptor_for_field ||= {}

      cache_key = [group, member_descriptor, field_name, fingerprint]

      # If no property is given, short circuit and memoize/return the given
      # descriptor
      @group_member_descriptor_for_field[cache_key] = member_descriptor unless field_name

      # Return memoized value even if it's nil
      return @group_member_descriptor_for_field[cache_key] if @group_member_descriptor_for_field.key?(cache_key)

      # In the query, this property was SELECTed using an AS with a fingerprint
      # to prevent collisions
      as = :"#{group.as}_#{fingerprint}_#{field_name}"

      # Look for any row in the results that include the original member
      sample_row = rows.find { |row| row[group.as] == member_descriptor }

      # That row will also have the meta property value that we're looking for
      @group_member_descriptor_for_field[cache_key] = sample_row&.dig(as) || ""
    end

    ##
    # Return the resolved exhibition value for the given group member
    # descriptor. In some cases this will simply return the descriptor itself.
    # If the dimension involved defines an exhibit property, this will look
    # through the result data to find the value for that property associated
    # with the given member.
    #
    # For example, if the group's dimension is podcast_id, the descriptor will
    # be an ID number like 123. This would look for the podcast_name value
    # associated with podcast 123, since podcast_name is the exhibit property
    # of podcast_id.
    #
    # This is intended to translate a member descriptor to an exhibition once
    # you **already know** things are unique. After this translation, unique
    # descriptors may become the same exhibitions.

    def group_member_exhibition(group, member_descriptor)
      group_member_descriptor_for_field(group, member_descriptor, (group && DataSchemaUtil.field_definition(group.dimension)["ExhibitField"]), :exhibit)
    end

    def group_meta_descriptor(group, group_member_descriptor, meta_field_name)
      group_member_descriptor_for_field(group, group_member_descriptor, meta_field_name, :meta)
    end

    def group_sort_descriptor(group, group_member_descriptor, sort_field_name)
      group_member_descriptor_for_field(group, group_member_descriptor, sort_field_name, :sort)
    end
  end
end
