require "google/cloud/bigquery"

module Compositions
  class DimensionalComposition < BaseComposition
    def self.query_value
      "dimensional"
    end

    def self.from_params(params)
      composition = super

      composition.groups = Components::Group.all_from_params(params)
      composition.metrics = Components::Metric.all_from_params(params)

      composition
    end

    attr_accessor :metrics, :groups

    validate :all_metrics_are_valid, :includes_at_least_one_metric
    validate :group_order_is_correct, :all_groups_are_valid, :group_count_is_supported

    def query
      return unless valid?

      erb = ERB.new(File.read(File.join(Rails.root, "app", "queries", "big_query", "dimensional.sql.erb")))
      sql = erb.result(binding)

      @query ||= sql
    end

    def results
      return unless valid?

      @results ||= Results::Dimensional.new(self, self.class.big_query.query(query))
    end

    private

    def all_metrics_are_valid
      if (metrics || []).any? { |m| m.invalid? }
        errors.add(:metrics, :invalid_metrics, message: "must all be valid")
      end
    end

    def includes_at_least_one_metric
      if !metrics || metrics.size == 0
        errors.add(:metrics, "must include at least 1 selection")
      end
    end

    def all_groups_are_valid
      if (groups || []).compact.any? { |g| g.invalid? }
        errors.add(:groups, :invalid_groups, message: "must all be valid")
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
