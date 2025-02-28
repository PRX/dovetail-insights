module Results
  class Dimensional
    attr_reader :provider, :composition, :rows

    def initialize(composition, rows)
      @provider = :big_query
      @composition = composition
      @rows = rows
    end

    ##
    # Generates a CSV for the results.
    # TODO Refactor this

    def as_csv
      CSV.generate(headers: true) do |csv|
        headers = []

        # Add a column for each group (zero or more)
        # TODO dimension is not meaningful enough on its own. Needs to include
        # more info like "extract" and "HOUR" if necesasry
        composition.groups.each do |group|
          headers << group.dimension

          dimension_def = DataSchema.dimensions[group.dimension.to_s]
          if dimension_def.has_key?("ExhibitProperty")
            exhibit_property_name = dimension_def["ExhibitProperty"]

            headers << exhibit_property_name
          end
        end

        # Add a column for each metric (1 or more)
        composition.metrics.each do |metric|
          headers << metric.metric
        end

        # Add row of headers
        csv << headers

        if composition.groups.size == 0
          row = []

          composition.metrics.each do |metric|
            row << get_value(metric, nil, nil)
          end

          csv << row
        elsif composition.groups.size == 1
          group_1_unique_member_descriptors.each do |member|
            row = []
            row << member

            dimension_def = DataSchema.dimensions[composition.groups[0].dimension.to_s]
            if dimension_def.has_key?("ExhibitProperty")
              row << group_member_exhibition(composition.groups[0], member)
            end

            # Add values for each metric for this group
            composition.metrics.each do |metric|
              row << get_value(metric, member, nil)
            end

            csv << row
          end

          # Add values for each metric for groupless values
          row = ["UNKNOWN"]
          composition.metrics.each do |metric|
            row << get_value(metric, nil, nil)
          end
          csv << row
        elsif composition.groups.size == 2
          group_1_unique_member_descriptors.each do |group_1_member_descriptor|
            group_2_unique_member_descriptors.each do |group_2_member_descriptor|
              row = []
              row << group_1_member_descriptor
              row << group_member_exhibition(composition.groups[0], group_1_member_descriptor)
              row << group_2_member_descriptor
              row << group_member_exhibition(composition.groups[1], group_2_member_descriptor)

              composition.metrics.each do |metric|
                row << get_value(metric, group_1_member_descriptor, group_2_member_descriptor)
              end

              csv << row
            end

            row = []
            row << group_member_exhibition(composition.groups[0], group_1_member_descriptor)
            row << nil
            composition.metrics.each do |metric|
              row << get_value(metric, group_1_member_descriptor, nil)
            end
            csv << row
          end

          group_2_unique_member_descriptors.each do |group_2_member_descriptor|
            row = []
            row << nil
            row << group_member_exhibition(composition.groups[1], group_2_member_descriptor)
            composition.metrics.each do |metric|
              row << get_value(metric, nil, group_2_member_descriptor)
            end
            csv << row
          end

          row = []
          row << nil
          row << nil
          composition.metrics.each do |metric|
            row << get_value(metric, nil, nil)
          end
          csv << row
        end
      end
    end

    ##
    # Get a single, raw data point value from the results for a given tuple of
    # metric and group members. Every data point is associated with a metric,
    # but group members are optional.
    #
    # For example, if given (downloads, 123), this will look for the downloads
    # value for the member of the first group configured for the composition
    # that yielded these results that mathches 123. So if the composition is
    # using podcast_id as the group 1 dimension, this will look for the results
    # for for podcast_id=123, and return the necessary metric.
    #
    # If either member argument are explicitly set to +nil+, this returns
    # values that aren't associated with any member of that group in the data.
    # For example, (downloads, nil) would return the number of downloads not
    # associated with any country, if group 1's dimension were country.

    def get_value(metric, group_1_member_descriptor = false, group_2_member_descriptor = false)
      @value_cache ||= {}
      cache_key = [metric.metric, group_1_member_descriptor, group_2_member_descriptor]

      # Return memoized value even if it's nil
      return @value_cache[cache_key] if @value_cache.key?(cache_key)

      row = rows.find do |row|
        # Given a query that is grouping by podcast_id and continent, +row+ may
        # look something like this:
        # {podcast_id_MTVjMG: 3, podcast_id_MTVjMG_podcast_name: "the memory palace", continent_code_MDZjYTB: "SA", downloads_NzQzYzJ: 128}
        # +podcast_id_MTVjMG_podcast_name+ is podcast_name, and is included
        # because it's the exhibit property of podcast_id
        # If impressions were also selected for this query, the impressions for
        # (memory palace+SA) would also be included in this row, under a key
        # like +impressions_wxyz123+.
        #
        # If the results included data that did not belong to any continent,
        # that would might look like this:
        # {podcast_id_MTVjMG: 3, podcast_id_MTVjMG_podcast_name: "the memory palace", continent_code_MDZjYTB: nil, downloads_NzQzYzJ: 128}
        # Note how the continent_code field is +nil+.
        #
        # A query only grouping by podcast_id might look like this:
        # {podcast_id_MTVjMG: 3, MTVjMG_podcast_id_MTVjMG_podcast_namepodcast_name: "the memory palace", downloads_NzQzYzJ: 1,501}
        #
        # We are looking for the row that matches the given descriptors. This
        # assumes that the appropriate number of descriptors are provided for
        # the data. If, for example, only a group 1 podcast_id descriptor were
        # provided for the podcast_id+continent query, this would simply return
        # the first row for that podcast_id, which is not likely desired.
        #
        # Descriptors passed in for non-existent groups will be ignored.

        g1_test = true
        g2_test = true

        # If a descriptor is provided, check to see if this row matches that
        # value. This does **not** handles cases where the provided descriptor
        # is +nil+.
        g1_test = row[composition.groups[0].as] == group_1_member_descriptor if group_1_member_descriptor && composition.groups[0]
        g2_test = row[composition.groups[1].as] == group_2_member_descriptor if group_2_member_descriptor && composition.groups[1]

        # If the provided descriptor is +nil+, we want to find a row where the
        # value for that group is also +nil+.
        g1_test = row[composition.groups[0].as].nil? if group_1_member_descriptor.nil? && composition.groups[0]
        g2_test = row[composition.groups[1].as].nil? if group_2_member_descriptor.nil? && composition.groups[1]

        g1_test && g2_test
      end

      # If a row was found, return the value from that row for the given metric.
      # Currently, this returns +nil+ if no value was found. It does **not**
      # default to a value like +0+.
      @value_cache[cache_key] = row && row[metric.as]

      @value_cache[cache_key]
    end

    ##
    # Get the total for a metric. If a group and member is given, this will be
    # the total just for that member. If not, it will be the total for the
    # metric across the entire result.

    def get_total(metric, group = false, member = false)
      if group && member.nil?
        rows.filter { |row| row[group.as].nil? }.inject(0) { |sum, row| sum + row[metric.as] }
      elsif group && member
        rows.filter { |row| row[group.as] == member }.inject(0) { |sum, row| sum + row[metric.as] }
      else
        rows.inject(0) { |sum, row| sum + row[metric.as] }
      end
    end

    ##
    # tktk

    def get_min(metric, group = false, member = false)
      # TODO This should not icnlude nil group
      if group && member.nil?
        rows.filter { |row| row[group.as].nil? }.map { |row| row[metric.as] }.compact.min
      elsif group && member
        rows.filter { |row| row[group.as] == member }.map { |row| row[metric.as] }.compact.min
      else
        rows.map { |row| row[metric.as] }.compact.min
      end
    end

    ##
    # tktk

    def get_max(metric, group = false, member = false)
      # TODO This should not icnlude nil group
      if group && member.nil?
        rows.filter { |row| row[group.as].nil? }.map { |row| row[metric.as] }.compact.max
      elsif group && member
        rows.filter { |row| row[group.as] == member }.map { |row| row[metric.as] }.compact.max
      else
        rows.map { |row| row[metric.as] }.compact.max.blank?
      end
    end

    def get_arith_mean(metric, group1_member_descriptor = false, group2_member_descriptor = false)
      # TODO There may be cases where 0 is not the correct default for missing values

      if group1_member_descriptor
        # Get the mean for some group 1 member across all group 2 members
        values = group_2_unique_member_descriptors.map { |d| get_value(metric, group1_member_descriptor, d) || 0 }
        values.sum / group_2_unique_member_descriptors.size
      elsif group2_member_descriptor
        # Get the mean for some group 2 member across all group 1 members
        values = group_1_unique_member_descriptors.map { |d| get_value(metric, d, group2_member_descriptor) || 0 }
        values.sum / group_1_unique_member_descriptors.size
      else
        # Get the mean across all group 1 members
        values = group_1_unique_member_descriptors.map { |d| get_value(metric, d) || 0 }
        values.sum / group_1_unique_member_descriptors.size
      end
    end

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
          .map { |row| row[group.as] } # Map each row to the member descriptor for this group
          .compact
          .uniq
          # TODO It likely makes sense to move this sorting to the view, so it
          # can reflect the final label
          .sort { |a, b| group_member_exhibition(group, a) <=> group_member_exhibition(group, b) }
      end
    end

    def group_1_unique_member_descriptors
      @group_1_unique_member_descriptors ||= unique_group_member_descriptors(composition.groups[0])
    end

    def group_2_unique_member_descriptors
      @group_2_unique_member_descriptors ||= unique_group_member_descriptors(composition.groups[1])
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
      dimension_def = DataSchema.dimensions[group.dimension.to_s]

      if dimension_def.has_key?("ExhibitProperty")
        # The dimension used for this group has an exhibit property, so another
        # field is used as its display value.

        # Get the name of the exhibit property
        exhibit_property_name = dimension_def["ExhibitProperty"]

        # In the query, the exhibit property was SELECTed using an AS with a
        # particular format, to prevent collisions
        prop_as = :"#{group.as}_exhibit_#{exhibit_property_name}"

        # Look for any row in the results that include the original member
        sample_row = rows.find { |row| row[group.as] == member_descriptor }

        # That row will also have the exhibit property value that we're looking
        # for
        exhibit_value = sample_row[prop_as]

        # If for some reason the exhibt value did't come back as something
        # useful, fallback to the member descriptor
        exhibit_value.blank? ? member_descriptor : exhibit_value
      else
        member_descriptor
      end
    end

    def group_meta_descriptor(group, group_member_descriptor, meta_property_name)
      # In the query, the exhibit property was SELECTed using an AS with a
      # particular format, to prevent collisions
      meta_as = :"#{group.as}_meta_#{meta_property_name}"

      # Look for any row in the results that include the original member
      sample_row = rows.find { |row| row[group.as] == group_member_descriptor }

      # That row will also have the meta property value that we're looking for
      sample_row[meta_as]
    end
  end
end
