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
        @composition.groups.each do |group|
          headers << group.dimension
        end

        # Add a column for each metric (1 or more)
        @composition.metrics.each do |metric|
          headers << metric.metric
        end

        # Add row of headers
        csv << headers

        if @composition.groups.size == 0
          row = []

          @composition.metrics.each do |metric|
            row << get_value(metric, nil, nil)
          end

          csv << row
        elsif @composition.groups.size == 1
          group_1_unique_members.each do |member|
            row = [group_member_label(@composition.groups[0], member)]

            # Add values for each metric for this group
            @composition.metrics.each do |metric|
              row << get_value(metric, member, nil)
            end

            csv << row
          end

          # Add values for each metric for groupless values
          row = ["UNKNOWN"]
          @composition.metrics.each do |metric|
            row << get_value(metric, nil, nil)
          end
          csv << row
        elsif @composition.groups.size == 2
          group_1_unique_members.each do |group_1_member|
            group_2_unique_members.each do |group_2_member|
              row = []
              row << group_member_label(@composition.groups[0], group_1_member)
              row << group_member_label(@composition.groups[1], group_2_member)

              @composition.metrics.each do |metric|
                row << get_value(metric, group_1_member, group_2_member)
              end

              csv << row
            end

            row = []
            row << group_member_label(@composition.groups[0], group_1_member)
            row << nil
            @composition.metrics.each do |metric|
              row << get_value(metric, group_1_member, nil)
            end
            csv << row
          end

          group_2_unique_members.each do |group_2_member|
            row = []
            row << nil
            row << group_member_label(@composition.groups[1], group_2_member)
            @composition.metrics.each do |metric|
              row << get_value(metric, nil, group_2_member)
            end
            csv << row
          end

          row = []
          row << nil
          row << nil
          @composition.metrics.each do |metric|
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

    def get_value(metric, group1_member = false, group2_member = false)
      row = rows.find do |row|
        g1_test = true
        g2_test = true

        g1_test = row[@composition.groups[0].as] == group1_member if group1_member
        g2_test = row[@composition.groups[1].as] == group2_member if group2_member

        g1_test = row[@composition.groups[0].as].nil? if group1_member.nil? && @composition.groups[0]
        g2_test = row[@composition.groups[1].as].nil? if group2_member.nil? && @composition.groups[1]

        g1_test && g2_test
      end

      row && row[metric.as]
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
      if group && member.nil?
        rows.filter { |row| row[group.as].nil? }.map { |row| row[metric.as] }.compact.max
      elsif group && member
        rows.filter { |row| row[group.as] == member }.map { |row| row[metric.as] }.compact.max
      else
        rows.map { |row| row[metric.as] }.compact.max.blank?
      end
    end

    ##
    # If the composition that yielded these results had a group, this returns
    # an array with all the unique members of that group from the data set.

    def group_unique_members(index)
      if @composition.groups && @composition.groups[index]
        group = @composition.groups[index]

        # If the group has indices, we want to maintain the order of the
        # indices as they were defined
        if group.indices
          # These strings match how these groups are being created in the query
          # TODO Figure out a better solution
          members = group.indices.map { |i| "LT #{i}" }
          members.push("GTE #{group.indices.last}")
        else
          rows.map { |row| row[group.as] }.compact.uniq.sort { |a, b| group_member_label(group, a) <=> group_member_label(group, b) }
        end
      end
    end

    def group_1_unique_members
      @group_1_unique_members ||= group_unique_members(0)
    end

    def group_2_unique_members
      @group_2_unique_members ||= group_unique_members(1)
    end

    ##
    # Return the display label for the given group member. In some cases this
    # will simply return the member itself. If the dimension involved defines
    # an exhibit property, this will look through the result data to find the
    # value for that property associated with the given member.
    #
    # For example, if the group's dimension is podcast_id, the member will be
    # an ID number like 123. This would look for the podcast_name value
    # associated with podcast 123, since podcast_name is the exhibit property
    # of podcast_id.

    def group_member_label(group, member)
      dimension_def = DataSchema.dimensions[group.dimension.to_s]

      if dimension_def.has_key?("ExhibitProperty")
        # The dimension used for this group has an exhibit property, so another
        # field is used as its display value.

        # Get the name of the exhibit property
        exhibit_property_name = dimension_def["ExhibitProperty"]

        # In the query, the exhibit property was SELECTed using an AS with a
        # particular format, to prevent collisions
        prop_as = :"#{group.as}_#{exhibit_property_name}"

        # Look for any row in the results that include the original member
        sample_row = rows.find { |row| row[group.as] == member }

        # That row will also have the exhibit property value that we're looking
        # for
        exhibit_value = sample_row[prop_as]

        # If for some reason the exhibt value did't come back as something
        # useful, fallback to the member value
        exhibit_value.blank? ? member : exhibit_value
      else
        member
      end
    end
  end
end
