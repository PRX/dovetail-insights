require "google/cloud/bigquery"

module Compositions
  # The Dimensional lens allows a user to analyze 1 or more metrics, with 0, 1
  # or 2 dimension groups.

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
    caution :all_groups_are_safe
    caution :range_includes_future

    def query
      return unless valid?

      @query ||= begin
        shaper = QueryShapers::Bigquery::Dimensional.new(self)

        erb = ERB.new(File.read(Rails.root.join("app/queries/bigquery/dimensional.sql.erb").to_s))
        erb.result_with_hash(shaper.to_hash).gsub(/\n{3,}/, "\n\n") # Remove extra newlines
      end
    end

    ##
    # A single query to BigQuery can generate the results for a Dimension
    # analysis.

    def results
      return unless valid?

      @results ||= begin
        job = BigqueryClient.instance.query_job(query)
        job.wait_until_done!

        @bigquery_total_bytes_billed = job.stats["query"]["totalBytesBilled"].to_i

        Results::Dimensional.new(self, job.data)
      end
    end

    def as_json(options = {})
      obj = super

      obj[:groups] = groups.map { |g| g.as_json(options) } if groups.present?
      obj[:metrics] = metrics.map { |m| m.as_json(options) } if metrics.present?

      obj
    end

    private

    def all_metrics_are_valid
      if metrics&.any? { |m| m.invalid? }
        errors.add(:metrics, :invalid_metrics, message: "must all be valid")
      end
    end

    def includes_at_least_one_metric
      if !metrics || metrics.size == 0
        errors.add(:metrics, "must include at least 1 selection")
      end
    end

    def all_groups_are_valid
      if groups&.compact&.any? { |g| g.invalid? }
        errors.add(:groups, :invalid_groups, message: "must all be valid")
      end
    end

    def all_groups_are_safe
      if groups&.compact&.any? { |g| g.unsafe? }
        warnings.add(:groups, :unsafe_groups, message: "include configuration that may be unsafe")
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

    def range_includes_future
      warnings.add(:to, :includes_future, message: "extends into the future") if abs_to && abs_to > Time.now.utc
    end
  end
end
