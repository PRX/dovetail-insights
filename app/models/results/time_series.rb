module Results
  class TimeSeries < Dimensional
    attr_accessor :comparison_row_sets

    # TODO This should be able to fill in gaps
    def granularity_unique_member_descriptors
      @rows.map { |row| row[@composition.granularity_as] }.compact.uniq.sort
    end

    def get_value(metric, granularity_member, group1_member = false, group2_member = false)
      row = @rows.find do |row|
        granularity_test = row[@composition.granularity_as] == granularity_member

        g1_test = true
        g2_test = true

        g1_test = row[@composition.groups[0].as] == group1_member if group1_member
        g2_test = row[@composition.groups[1].as] == group2_member if group2_member

        g1_test = row[@composition.groups[0].as].nil? if group1_member.nil? && @composition.groups[0]
        g2_test = row[@composition.groups[1].as].nil? if group2_member.nil? && @composition.groups[1]

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
        rows.filter { |row| row[@composition.granularity_as] == granularity_member }.inject(0) { |sum, row| sum + row[metric.as] }
      else
        # rows.inject(0) { |sum, row| sum + row[metric.as] }
      end
    end

    def get_value_comparison(comparison, lookback, metric, granularity_member, group1_member = false, group2_member = false)
      return get_value(metric, granularity_member, group1_member, group2_member) unless comparison

      idx = @composition.comparisons.index(comparison)

      # +rows+ here will be the query result for a single lookback for a single
      # comparison.
      rows = comparison_row_sets[idx][lookback]

      row = rows.find do |row|
        comparison_member = case comparison.period
        when :YoY
          granularity_member.advance(years: lookback)
        when :QoQ
          granularity_member.advance(months: 3 * lookback)
        when :WoW
          granularity_member.advance(weeks: lookback)
        end

        granularity_test = row[@composition.granularity_as] == comparison_member

        g1_test = true
        g2_test = true

        g1_test = row[@composition.groups[0].as] == group1_member if group1_member
        g2_test = row[@composition.groups[1].as] == group2_member if group2_member

        g1_test = row[@composition.groups[0].as].nil? if group1_member.nil? && @composition.groups[0]
        g2_test = row[@composition.groups[1].as].nil? if group2_member.nil? && @composition.groups[1]

        granularity_test && g1_test && g2_test
      end

      row && row[metric.as]
    end
  end
end
