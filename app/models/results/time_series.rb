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

    def granularity_unique_member_descriptors
      # Keeping this here for checking actual values coming out of the query
      # return @rows.map { |row| row[composition.granularity_as] }.compact.uniq.sort

      # Truncate the time range end based on chosen granularity
      end_grain = case composition.granularity
      when :daily
        composition.abs_to.beginning_of_day
      when :weekly
        composition.abs_to.beginning_of_week(:sunday)
      when :monthly
        composition.abs_to.beginning_of_month
      when :quarterly
      # TODO
      when :yearly
        Time.new(composition.abs_to.year, 1, 1)
      when :rolling
        # TODO May not be correct
        composition.abs_to
      end

      # Make a list to hold all the descriptors
      descriptors = [end_grain.strftime("%Y-%m-%dT%H:%M:%SZ")]

      # Starting from the end, step back 1 week/month/etc based on chosen
      # granularity, until we're before the time range start
      current_grain = end_grain
      while current_grain > composition.abs_from
        current_grain = case composition.granularity
        when :daily
          current_grain.advance(days: -1)
        when :weekly
          current_grain.advance(weeks: -1)
        when :monthly
          current_grain.advance(months: -1)
        when :quarterly
          # TODO
        when :yearly
          current_grain.advance(years: -1)
        when :rolling
          current_grain.advance(seconds: -1 * composition.window)
        end

        descriptors << current_grain.strftime("%Y-%m-%dT%H:%M:%SZ")
      end

      # We know have a list of all necessary descriptors for this range and
      # granularity, but it's backwards. Reverse it to correct that. This set
      # may also be inclusive of the time range end, so filter things out to
      # enforce the time range end being LT.
      descriptors.reverse.filter { |m| m < composition.abs_to }
    end

    def get_value(metric, granularity_member, group1_member = false, group2_member = false)
      row = @rows.find do |row|
        p "ROW  #{row[composition.granularity_as]}"
        p "GEN #{granularity_member}"
        granularity_test = row[composition.granularity_as] == granularity_member

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

    def get_total(metric, granularity_member)
      if granularity_member
        rows.filter { |row| row[composition.granularity_as] == granularity_member }.inject(0) { |sum, row| sum + row[metric.as] }
      else
        # TODO Suppport overall metric totals?
        # rows.inject(0) { |sum, row| sum + row[metric.as] }
      end
    end

    def get_value_comparison(comparison, rewind, metric, granularity_member, group1_member = false, group2_member = false)
      return get_value(metric, granularity_member, group1_member, group2_member) unless comparison

      results_for_this_comparison = comparison_results[comparison.period]

      # When comparison.lookback=5, rewind will be something like -5, which
      # is the first item in the array, so 5 + -5 = 0. The most recent comparison
      # data will be rewind = -1, so 5 + -1 = 4
      idx = comparison.lookback + rewind

      rows_for_this_lookback = results_for_this_comparison[idx]

      row = rows_for_this_lookback.find do |row|
        comparison_member = case comparison.period
        when :YoY
          granularity_member.advance(years: rewind)
        when :QoQ
          granularity_member.advance(months: 3 * rewind)
        when :WoW
          granularity_member.advance(weeks: rewind)
        end

        granularity_test = row[composition.granularity_as] == comparison_member

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

    def get_total_comparison(comparison, rewind, metric, granularity_member)
      if granularity_member
        results_for_this_comparison = comparison_results[comparison.period]

        idx = comparison.lookback + rewind

        rows_for_this_lookback = results_for_this_comparison[idx]

        (rows_for_this_lookback.filter do |row|
          comparison_member = case comparison.period
          when :YoY
            granularity_member.advance(years: rewind)
          when :QoQ
            granularity_member.advance(months: 3 * rewind)
          when :WoW
            granularity_member.advance(weeks: rewind)
          end

          row[composition.granularity_as] == comparison_member
        end).inject(0) { |sum, row| sum + row[metric.as] }
      else
        # TODO Suppport overall metric totals?
        # rows.inject(0) { |sum, row| sum + row[metric.as] }
      end
    end
  end
end
