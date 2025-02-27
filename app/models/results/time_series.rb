module Results
  class TimeSeries < Dimensional
    # A hash where each key is some comparison, and the value is an array of
    # the all the query job datas.
    # { YoY: [ 2022_rows, 2023_rows, 2024_rows ] }
    attr_accessor :comparison_results

    ##
    # We build this list of descriptors manually so that they are continuous
    # within the time range, even if there is no data for all weeks/months/etc.
    #
    # This must produce a set of descriptors that is compatible with the query
    # results, so that looking up values using these descriptors works as
    # expected.
    #
    # These descriptors are always strings like "2023-01-01T12:34:56Z"

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

      # We know have a list of all necessary descriptors for this range and
      # granularity, but it's backwards. Reverse it to correct that. This set
      # may also be inclusive of the time range end, so filter things out to
      # enforce the time range end being LT.
      @unique_interval_descriptors = descriptors.reverse.filter { |m| m < composition.abs_to }

      @unique_interval_descriptors
    end

    def get_value(metric, interval_descriptor, group1_member = false, group2_member = false)
      row = @rows.find do |row|
        granularity_test = row[composition.granularity_as] == interval_descriptor

        g1_test = true
        g2_test = true

        g1_test = row[composition.groups[0].as] == group1_member if group1_member
        g2_test = row[composition.groups[1].as] == group2_member if group2_member

        g1_test = row[composition.groups[0].as].nil? if group1_member.nil? && composition.groups[0]
        g2_test = row[composition.groups[1].as].nil? if group2_member.nil? && composition.groups[1]

        granularity_test && g1_test && g2_test
      end

      row && row[metric.as]
    end

    ##
    # Get the total for a metric. If a group and member is given, this will be
    # the total just for that member. If not, it will be the total for the
    # metric across the entire result.

    def get_total(metric, interval)
      if interval
        rows.filter { |row| row[composition.granularity_as] == interval }.inject(0) { |sum, row| sum + row[metric.as] }
      else
        # TODO Suppport overall metric totals?
        # rows.inject(0) { |sum, row| sum + row[metric.as] }
      end
    end

    def get_value_comparison(comparison, rewind, metric, interval_descriptor, group1_member = false, group2_member = false)
      return get_value(metric, interval_descriptor, group1_member, group2_member) unless comparison

      results_for_this_comparison = comparison_results[comparison.period]

      # When comparison.lookback=5, rewind will be something like -5, which
      # is the first item in the array, so 5 + -5 = 0. The most recent comparison
      # data will be rewind = -1, so 5 + -1 = 4
      idx = comparison.lookback + rewind

      rows_for_this_lookback = results_for_this_comparison[idx]

      interval_timestamp = Time.parse(interval_descriptor)

      row = rows_for_this_lookback.find do |row|
        comparison_member = case comparison.period
        when :YoY
          interval_timestamp.advance(years: rewind)
        when :QoQ
          interval_timestamp.advance(months: 3 * rewind)
        when :WoW
          interval_timestamp.advance(weeks: rewind)
        end

        granularity_test = row[composition.granularity_as] == comparison_member.strftime("%Y-%m-%dT%H:%M:%SZ")

        g1_test = true
        g2_test = true

        g1_test = row[composition.groups[0].as] == group1_member if group1_member
        g2_test = row[composition.groups[1].as] == group2_member if group2_member

        g1_test = row[composition.groups[0].as].nil? if group1_member.nil? && composition.groups[0]
        g2_test = row[composition.groups[1].as].nil? if group2_member.nil? && composition.groups[1]

        granularity_test && g1_test && g2_test
      end

      row && row[metric.as]
    end

    def get_total_comparison(comparison, rewind, metric, interval_descriptor)
      if interval_descriptor
        results_for_this_comparison = comparison_results[comparison.period]

        idx = comparison.lookback + rewind

        rows_for_this_lookback = results_for_this_comparison[idx]

        interval_timestamp = Time.parse(interval_descriptor)

        (rows_for_this_lookback.filter do |row|
          comparison_member = case comparison.period
          when :YoY
            interval_timestamp.advance(years: rewind)
          when :QoQ
            interval_timestamp.advance(months: 3 * rewind)
          when :WoW
            interval_timestamp.advance(weeks: rewind)
          end

          row[composition.granularity_as] == comparison_member.strftime("%Y-%m-%dT%H:%M:%SZ")
        end).inject(0) { |sum, row| sum + row[metric.as] }
      else
        # TODO Suppport overall metric totals?
        # rows.inject(0) { |sum, row| sum + row[metric.as] }
      end
    end
  end
end
