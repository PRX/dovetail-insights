module Results
  class TimeSeries < Dimensional
    # A hash where each key is some comparison, and the value is an array of
    # the all the query job datas.
    # { YoY: [ 2022_rows, 2023_rows, 2024_rows ], QoQ: [22Q1_row, 22Q2_rows] }
    attr_accessor :comparison_results

    ##
    # See Results::Dimensional#as_csv for more details on how this works.

    def as_csv
      CSV.generate(headers: true) do |csv|
        headers = []

        headers << "Interval"

        # Add a column for each group (zero or more)
        composition.groups.each do |group|
          headers << ApplicationController.helpers.prop_or_dim_label(group.dimension, group)

          dimension_def = DataSchemaUtil.field_definition(group.dimension)
          if dimension_def.has_key?("ExhibitField")
            exhibit_field_name = dimension_def["ExhibitField"]

            headers << ApplicationController.helpers.prop_or_dim_label(exhibit_field_name, group)
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

        group_1_unique_member_descriptors_with_nil = group_1_unique_member_descriptors + [nil] if group_1_unique_member_descriptors
        group_2_unique_member_descriptors_with_nil = group_2_unique_member_descriptors + [nil] if group_2_unique_member_descriptors

        unique_interval_descriptors.each do |interval_descriptor|
          (group_1_unique_member_descriptors_with_nil || [false]).each do |group_1_descriptor|
            (group_2_unique_member_descriptors_with_nil || [false]).each do |group_2_descriptor|
              row = []

              row << interval_descriptor

              composition.groups.each_with_index do |group, idx|
                descriptor = group_1_descriptor if idx == 0 && (group_1_descriptor || group_1_descriptor.nil?)
                descriptor = group_2_descriptor if idx == 1 && (group_2_descriptor || group_2_descriptor.nil?)

                if descriptor || descriptor.nil?
                  row << if group.indices
                    ApplicationController.helpers.member_label(composition, group, descriptor)
                  else
                    descriptor || ""
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
                row << lookup_data_point(metric, interval_descriptor, nil, nil, group_1_descriptor, group_2_descriptor)
              end

              csv << row
            end
          end
        end

        csv
      end
    end

    ##
    # We build this list of descriptors manually so that they are continuous
    # within the time range, even if there is no data for all weeks/months/etc.
    #
    # This must produce a set of descriptors that is compatible with the query
    # results, so that looking up values using these descriptors works as
    # expected.
    #
    # These descriptors are always strings like "2023-01-01T12:34:56Z".
    # Interval descriptors represent the beginning of the interval.

    def unique_interval_descriptors
      # Keeping this here for checking actual values coming out of the query
      # return @rows.map { |row| row[composition.granularity_as] }.compact.uniq.sort

      return @unique_interval_descriptors if @unique_interval_descriptors

      # Truncate the time range end based on chosen granularity
      final_interval = case composition.granularity
      when :daily
        composition.abs_to.beginning_of_day
      when :weekly
        composition.abs_to.beginning_of_week(:sunday)
      when :monthly
        composition.abs_to.beginning_of_month
      when :quarterly
        composition.abs_to.beginning_of_quarter
      when :yearly
        Time.new(composition.abs_to.year, 1, 1)
      when :rolling
        composition.abs_to
      end

      # Make a list to hold all the descriptors
      descriptors = [final_interval.strftime("%Y-%m-%dT%H:%M:%SZ")]

      # Starting from the end, step back 1 week/month/etc based on chosen
      # granularity, until we're before the time range start
      current_interval = final_interval
      while current_interval > composition.abs_from
        current_interval = case composition.granularity
        when :daily
          current_interval.advance(days: -1)
        when :weekly
          current_interval.advance(weeks: -1)
        when :monthly
          current_interval.advance(months: -1)
        when :quarterly
          current_interval.advance(months: -3)
        when :yearly
          current_interval.advance(years: -1)
        when :rolling
          current_interval.advance(seconds: -1 * composition.window)
        end

        descriptors << current_interval.strftime("%Y-%m-%dT%H:%M:%SZ")
      end

      # We now have a list of all necessary descriptors for this range and
      # granularity, but it's backwards. Reverse it to correct that. This set
      # may also be inclusive of the time range end, so filter things out to
      # enforce the time range end being LT.
      @unique_interval_descriptors = descriptors.reverse.filter { |m| m < composition.abs_to }

      @unique_interval_descriptors
    end

    def comparison_descriptor_for_interval_descriptor(interval_descriptor, comparison, rewind)
      raise "Must include a rewind when including a comparison" if comparison && !rewind
      raise "Must include a comparison when including a rewind" if rewind && !comparison

      return interval_descriptor if !comparison

      interval_timestamp = Time.parse(interval_descriptor)

      comparison_descriptor = case comparison.period
      when :YoY
        interval_timestamp.advance(years: rewind)
      when :QoQ
        interval_timestamp.advance(months: 3 * rewind)
      when :WoW
        interval_timestamp.advance(weeks: rewind)
      end

      comparison_descriptor.strftime("%Y-%m-%dT%H:%M:%SZ")
    end

    ##
    # Returns all the rows from the results for the given comparison and
    # lookback, or the base results if no comparison is given

    def rows_for_comparison(comparison = nil, rewind = nil)
      raise "Must include a rewind when including a comparison" if comparison && !rewind
      raise "Must include a comparison when including a rewind" if rewind && !comparison

      if !comparison
        rows
      else
        results_for_this_comparison = comparison_results[comparison.period]

        # When comparison.lookback=5, rewind will be something like -5, which
        # is the first item in the array, so 5 + -5 = 0. The most recent comparison
        # data will be rewind = -1, so 5 + -1 = 4
        idx = comparison.lookback + rewind

        results_for_this_comparison[idx]
      end
    end

    ##
    # See Results::Dimension#get_value for a description of how this works

    def lookup_data_point(metric, interval_descriptor, comparison = nil, rewind = nil, group_1_member_descriptor = false, group_2_member_descriptor = false)
      raise "Must include a rewind when including a comparison" if comparison && !rewind
      raise "Must include a comparison when including a rewind" if rewind && !comparison

      @lookup_data_point_cache ||= {}
      cache_key = [metric.metric, interval_descriptor, comparison, rewind, group_1_member_descriptor, group_2_member_descriptor]

      # Return memoized value even if it's nil
      return @lookup_data_point_cache[cache_key] if @lookup_data_point_cache.key?(cache_key)

      rows_to_use = rows_for_comparison(comparison, rewind)

      descriptor_to_use = comparison_descriptor_for_interval_descriptor(interval_descriptor, comparison, rewind)

      row = rows_to_use.find do |row|
        granularity_test = row[composition.granularity_as] == descriptor_to_use

        g1_test = true
        g2_test = true

        g1_test = row[composition.groups[0].as] == group_1_member_descriptor if group_1_member_descriptor && composition.groups[0]
        g2_test = row[composition.groups[1].as] == group_2_member_descriptor if group_2_member_descriptor && composition.groups[1]

        g1_test = row[composition.groups[0].as].nil? if group_1_member_descriptor.nil? && composition.groups[0]
        g2_test = row[composition.groups[1].as].nil? if group_2_member_descriptor.nil? && composition.groups[1]

        granularity_test && g1_test && g2_test
      end

      # If a row was found, return the value from that row for the given metric.
      # Currently, this returns +nil+ if no value was found. It does **not**
      # default to a value like +0+.
      @lookup_data_point_cache[cache_key] = row && row[metric.as]
    end

    def calc_interval_sum(metric, interval_descriptor, comparison = nil, rewind = nil)
      raise "Must include a rewind when including a comparison" if comparison && !rewind
      raise "Must include a comparison when including a rewind" if rewind && !comparison

      @calc_interval_sum_cache ||= {}
      cache_key = [metric, interval_descriptor, comparison, rewind]

      # Return memoized value even if it's nil
      return @calc_interval_sum_cache[cache_key] if @calc_interval_sum_cache.key?(cache_key)

      rows_to_use = rows_for_comparison(comparison, rewind)

      descriptor_to_use = comparison_descriptor_for_interval_descriptor(interval_descriptor, comparison, rewind)

      @calc_interval_sum_cache[cache_key] = rows_to_use.filter { |row| row[composition.granularity_as] == descriptor_to_use }.inject(0) { |sum, row| sum + row[metric.as] }
    end
  end
end
