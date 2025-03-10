module Results
  class Dimensional
    attr_reader :provider, :composition, :rows

    def initialize(composition, rows)
      @provider = :bigquery
      @composition = composition
      @rows = rows
    end

    ##
    # Generates a CSV for the results.

    def as_csv
      CSV.generate(headers: true) do |csv|
        headers = []

        # Add a column for each group (zero or more)
        composition.groups.each do |group|
          headers << ApplicationController.helpers.prop_or_dim_label(group.dimension, group)

          dimension_def = DataSchemaUtil.field_definition(group.dimension)
          if dimension_def.has_key?("ExhibitField")
            exhibit_property_name = dimension_def["ExhibitField"]

            headers << ApplicationController.helpers.prop_or_dim_label(exhibit_property_name, group)
          end

          group&.meta&.each do |meta_field_name|
            headers << ApplicationController.helpers.prop_or_dim_label(meta_field_name, group)
          end
        end

        # Add a column for each metric (1 or more)
        composition.metrics.each do |metric|
          headers << metric.metric
        end

        # Add row of headers
        csv << headers

        (group_1_unique_member_descriptors || [false]).each do |group_1_descriptor|
          (group_2_unique_member_descriptors || [false]).each do |group_2_descriptor|
            row = []

            composition.groups.each_with_index do |group, idx|
              descriptor = group_1_descriptor if idx == 0 && group_1_descriptor
              descriptor = group_2_descriptor if idx == 1 && group_2_descriptor

              if descriptor
                row << if group.indices
                  ApplicationController.helpers.member_label(composition, group, descriptor)
                else
                  descriptor
                end

                dimension_def = DataSchemaUtil.field_definition(group.dimension)
                if dimension_def.has_key?("ExhibitField")
                  row << group_member_exhibition(group, descriptor)
                end

                group&.meta&.each do |meta_field_name|
                  row << group_meta_descriptor(group, descriptor, meta_field_name)
                end
              end
            end

            composition.metrics.each do |metric|
              row << lookup_data_point(metric, group_1_descriptor, group_2_descriptor)
            end

            csv << row
          end
        end

        csv
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

    def lookup_data_point(metric, group_1_member_descriptor = false, group_2_member_descriptor = false)
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
    end

    def calc(aggregation, metric, group, member_descriptor)
      case aggregation
      when :sum
        calc_sum(metric, group, member_descriptor)
      when :min
        calc_min(metric, group, member_descriptor)
      when :max
        calc_max(metric, group, member_descriptor)
      when :range
        calc_range(metric, group, member_descriptor)
      when :arithmetic_mean
        calc_arithmetic_mean(metric, group, member_descriptor)
      end
    end

    ##
    # Get the total for a metric. If a group and member is given, this will be
    # the total just for that member. If not, it will be the total for the
    # metric across the entire result.

    def calc_sum(metric, group = false, member_descriptor = false)
      @calc_sum_cache ||= {}
      cache_key = [metric.metric, group, member_descriptor]

      # Return memoized value even if it's nil
      return @calc_sum_cache[cache_key] if @calc_sum_cache.key?(cache_key)

      @calc_sum_cache[cache_key] = if group && member_descriptor.nil?
        rows.filter { |row| row[group.as].nil? }.inject(0) { |sum, row| sum + row[metric.as] }
      elsif group && member_descriptor
        rows.filter { |row| row[group.as] == member_descriptor }.inject(0) { |sum, row| sum + row[metric.as] }
      else
        rows.inject(0) { |sum, row| sum + row[metric.as] }
      end
    end

    ##
    #

    def foo(metric, group = false, member_descriptor = false)
      # If there are groups, we don't want to include nils. For example, if the
      # results had { US: 200, CA: 50: nil: 3 }, we want to return 50, not 3,
      # since that's the actual minimum associated with a discrete country.

      # We know there is at least 1 group
      g1 = composition.groups[0]
      g2 = composition.groups[1]

      # Passing in no group when there are two groups is undefined behavior
      raise "tktk" if !group && g2

      (rows
        .filter do |row|
          if group
            # If a group is given, only select rows matching the given descriptor
            # for that group
            member_descriptor.nil? ? row[group.as].nil? : row[group.as] == member_descriptor
          else
            # If no group is given, we know there's no group 2 because of the
            # +raise+ above, and we can assume that we're looking for the min
            # across group 1 members, so we want to include all rows
            next true
          end
        end).filter do |row|
        if !group
          # Include rows that aren't nil in group 1
          !row[g1.as].nil?
        elsif g2
          # Include rows that aren't nil in the other group
          group_idx = composition.groups.index(group)
          !row[composition.groups[1 - group_idx].as].nil?
        else
          # Include all rows
          true
        end
      end
    end

    ##
    # tktk

    def calc_min(metric, group = false, member_descriptor = false)
      @calc_min_cache ||= {}
      cache_key = [metric.metric, group, member_descriptor]

      # Return memoized value even if it's nil
      return @calc_min_cache[cache_key] if @calc_min_cache.key?(cache_key)

      # When there are no groups, we don't need to worry about nils, so
      # simply take the min of all values for the given metric
      return @calc_min_cache[cache_key] = rows.map { |row| row[metric.as] }.compact.min unless composition.groups

      bar = foo(metric, group, member_descriptor)
      @calc_min_cache[cache_key] = bar.map { |row| row[metric.as] }.compact.min
    end

    ##
    # tktk

    def calc_max(metric, group = false, member_descriptor = false)
      @calc_max_cache ||= {}
      cache_key = [metric.metric, group, member_descriptor]

      # Return memoized value even if it's nil
      return @calc_max_cache[cache_key] if @calc_max_cache.key?(cache_key)

      # When there are no groups, we don't need to worry about nils, so
      # simply take the min of all values for the given metric
      return @calc_max_cache[cache_key] = rows.map { |row| row[metric.as] }.compact.max unless composition.groups

      bar = foo(metric, group, member_descriptor)
      @calc_max_cache[cache_key] = bar.map { |row| row[metric.as] }.compact.max
    end

    def calc_arithmetic_mean(metric, group = false, member_descriptor = false)
      @calc_arith_mean_cache ||= {}
      cache_key = [metric.metric, group, member_descriptor]

      # Return memoized value even if it's nil
      return @calc_arith_mean_cache[cache_key] if @calc_arith_mean_cache.key?(cache_key)

      # When there are no groups, we don't need to worry about nils, so
      # simply take the min of all values for the given metric
      return @calc_arith_mean_cache[cache_key] = calc_sum(metric, group, member_descriptor) unless composition.groups

      bar = foo(metric, group, member_descriptor)
      sum = bar.inject(0) { |sum, row| sum + row[metric.as] }
      @calc_arith_mean_cache[cache_key] = sum / bar.size
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

      cache_key = [group&.dimension&.to_s, member_descriptor, field_name, fingerprint]

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
