module Compositions
  ##
  # TODO tktk

  class CumeComposition < BaseComposition
    def self.query_value
      "cume"
    end

    def self.from_params(params)
      composition = super

      composition.groups = Components::Group.all_from_params(params)
      composition.metrics = Components::Metric.all_from_params(params)

      composition.window = DurationShorthand.expand(params[:window]) if params[:window].present?

      # TODO These overrides should always happen when initializing an instance,
      # not just when from_params. Probably these overrides should be added
      # in #initialize, and this should remove any conflicts that are created
      # by params

      # Delete any existing pubdate filter and add one that matches the from/to
      pub_date_filter = composition&.filters&.find { |filter| filter.dimension == :episode_publish_timestamp }
      composition&.filters&.delete(pub_date_filter) if pub_date_filter
      if composition.from && composition.to
        filter = Compositions::Components::Filter.new(:episode_publish_timestamp)
        filter.operator = :include
        filter.from = composition.from
        filter.to = composition.to
        composition.filters ||= []
        composition.filters << filter
      end

      composition
    end

    attr_accessor :metrics, :groups
    attr_reader :window

    # TODO Validate that pubdate filter exists and includes a subset of the composition time range
    validates :window, presence: true
    validate :window_is_supported
    validate :all_metrics_are_valid, :includes_at_least_one_metric
    validate :group_order_is_correct, :all_groups_are_valid, :group_count_is_supported
    validate :required_episode_id_group
    caution :all_groups_are_safe
    caution :range_includes_future

    def window=(window)
      raise "Window must be an integer" unless window.instance_of? Integer

      @window = window
    end

    def query
      return unless valid?

      @query ||= begin
        shaper = QueryShapers::Bigquery::Cume.new(self)

        erb = ERB.new(File.read(Rails.root.join("app/queries/bigquery/cume.sql.erb").to_s))
        erb.result_with_hash(shaper.to_hash).gsub(/\n{3,}/, "\n\n")
      end
    end

    def results
      return unless valid?

      @results ||= begin
        job = BigqueryClient.instance.query_job(query)
        job.wait_until_done!

        @bigquery_total_bytes_billed = job.stats["query"]["totalBytesBilled"].to_i

        Results::Cume.new(self, job.data)
      end
    end

    def as_json(options = {})
      obj = super

      obj[:groups] = groups.map { |g| g.as_json(options) } if groups
      obj[:metrics] = metrics.map { |m| m.as_json(options) } if metrics
      obj[:window] = window if window

      obj
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

    def all_groups_are_safe
      if (groups || []).compact.any? { |g| g.unsafe? }
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
        unless groups.size >= 1 && groups.size <= 1
          # TODO Increase once there's backend/results UI support for more groups
          errors.add(:groups, "must include between 1 and 1 groups, but had #{groups.size}")
        end
      end
    end

    def required_episode_id_group
      if !groups || !groups[0] || groups[0].dimension != :episode_id
        errors.add(:groups, "must set episode_id as group 1")
      end
    end

    def range_includes_future
      warnings.add(:to, :includes_future, message: "extends into the future") if abs_to && abs_to > Time.now.utc
    end

    def window_is_supported
      if window.present?
        errors.add(:window, "must be at least 12 hours") if window < 12 * 3_600
        # The app support windows as small as 1 second, so this could be
        # expanded if desired
        errors.add(:window, "must be a whole number of minutes") if window % 60 != 0
      end
    end
  end
end
