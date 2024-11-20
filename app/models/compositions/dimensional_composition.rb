require "google/cloud/bigquery"

module Compositions
  class DimensionalComposition < BaseComposition
    def self.query_value
      "dimensional"
    end

    def self.from_params(params)
      composition = super

      composition.groups = Components::Group.from_params(params)
      composition.metrics = Components::Metric.from_params(params)

      composition
    end

    attr_accessor :metrics, :groups

    validate :each_metric_is_valid, :includes_at_least_one_metric
    validate :group_order_is_correct, :each_group_is_valid, :group_count_is_supported

    def query
      return unless valid?

      erb = ERB.new(File.read(File.join(Rails.root, "app", "queries", "big_query", "dimensional.sql.erb")))
      sql = erb.result(binding)

      @query ||= sql
    end

    def results
      return unless valid?

      bigquery = Google::Cloud::Bigquery.new
      @results ||= Results::Dimensional.new(self, bigquery.query(query))
    end

    private

    def each_metric_is_valid
      (metrics || []).each do |metric|
        unless metric.valid?
          metric.errors.each do |e|
            # TODO Not sure which attribute to add these to yet
            errors.add("metric.#{metric.metric}", e.full_message)
          end
        end
      end
    end

    def includes_at_least_one_metric
      if !metrics || metrics.size == 0
        errors.add(:metrics, "must include at least 1 selection")
      end
    end

    def each_group_is_valid
      # TODO Change this to all_groups_are_valid and just add one error
      (groups || []).each do |group|
        next if !group # If group 2 is selected but not group 1, group[0] will be nil

        unless group.valid?
          group.errors.each do |e|
            # TODO Not sure which attribute to add these to yet
            errors.add("group.#{group.dimension}", e.full_message)
          end
        end
      end
    end

    def group_order_is_correct
      if groups && groups[1] && !groups[0]
        errors.add(:groups, "must include group 1 before adding group 2")
      end
    end

    def group_count_is_supported
      if groups
        unless groups.size >= 0 && groups.size <= 2
          errors.add(:groups, "must include between 0 and 2 groups, but had #{groups.size}")
        end
      end
    end
  end
end
