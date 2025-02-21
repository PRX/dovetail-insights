module Compositions
  ##
  # The Time Series lens allows users to analyze 1 or more metrics, aggregated
  # by some temporal buckets (daily, monthly, etc), and then by 0, 1 or 2
  # dimension groups.
  #
  # Additionally, comparisons to related historical data can be included in the
  # results. See +#results+ for information about how comparisons affect the
  # number of queries being made.

  class TimeSeriesComposition < DimensionalComposition
    def self.query_value
      "timeSeries"
    end

    def self.from_params(params)
      composition = super

      composition.granularity = params[:granularity].to_sym if params[:granularity]

      # TODO This converts the value to seconds in the form, which is a hostile
      if /^[0-9]+D$/.match?(params[:window])
        days = params[:window].match(/^([0-9]+)D$/)[1].to_i
        composition.window = days * 86400
      elsif params[:window]
        composition.window = params[:window].to_i if params[:window].present?
      end

      composition.comparisons = Components::Comparison.all_from_params(params)

      composition
    end

    attr_reader :granularity, :window, :comparisons

    validates :granularity, presence: true
    validate :rolling_must_have_window, :window_only_supported_with_rolling, :window_is_supported
    validate :each_comparions_is_valid, :comparisons_are_unique, :comparison_count_is_correct
    validates :granularity, inclusion: {in: [:daily, :weekly, :monthly, :quarterly, :yearly, :rolling], message: "is not a supported value"}
    validate :comparisons_are_supported_granularity
    validate :rolling_uniques_period_exceeds_interval

    # TODO Validate that comparisons are supported for the selected granularity
    # TODO Validate metrics (may be different validations than with dimensional lens)

    def granularity=(granularity)
      raise unless granularity.instance_of? Symbol

      @granularity = granularity
    end

    def window=(window)
      # TODO This value should be in seconds, and should support both raw input
      # in seconds from the form, and more friendly input like "7D" and convert
      # the days to seconds
      raise unless window.instance_of? Integer

      @window = window
    end

    def granularity_as
      @granularity_as ||= Base64.strict_encode64(SecureRandom.uuid).to_sym
    end

    def rolling?
      granularity == :rolling && window && window > 0
    end

    def comparisons=(comparisons)
      raise if comparisons.any? { |c| !c.instance_of? Components::Comparison }

      @comparisons ||= comparisons
    end

    def query(a_binding)
      return unless valid?

      erb = ERB.new(File.read(File.join(Rails.root, "app", "queries", "big_query", "time_series.sql.erb")))
      erb.result(a_binding)
    end

    ##
    # When the composition includes comparisons, each comparision is made up of
    # a +period+ (like, week-over-week or year-over-year) and a +lookback+ (the
    # number of previous weeks or years to compare). A query is made to
    # BigQuery for _each lookback_.
    #
    # For example, if the composition includes a YoY comparison and a WoW
    # comparison, and the YoY comparison has a lookback of 5 and the WoW
    # comparison has a lookback of 10, that would resultin 16 total queries
    # being made to BigQuery: one for the standard results, and an additional
    # query for each lookback interval.

    def results
      # TODO Refactor
      return unless valid?

      return @results if @results

      @big_query_total_bytes_billed = 0

      base_jobs = []
      compare_jobs = []
      threads = []

      thread = Thread.new do
        base_jobs << BigQueryClient.instance.query_job(query(binding))
      end
      threads << thread

      # Add +comparison_row_sets+ for each comparison required
      # TODO Make sure these row_sets are added to the array at the same
      # position as the comparison in #comparisons
      # TODO Putting all the row sets into single array won't really work if
      # there are multiple comparions, which isn't currently supported
      # TODO Make these BigQuery requests concurrently
      (comparisons || []).each_with_index do |comparison, i|
        # base_results.comparison_row_sets[i] = [] if base_results.comparison_row_sets[i].nil?

        # Override this compositions from/to values to reflect the range for
        # the comparisons.
        #
        # For example if the composition's from is 2024-05-05, and the
        # comparison is +:YoY+, with a lookback of +2+, we need to run two
        # additional queries: one where the from is 2023-05-05, and one where
        # the from is 2022-05-05.
        #
        # The results from all the comparison queries are held in an array. The
        # oldest results should appear earliest in the array (so the 2022 query
        # from the above example).
        comparison.lookback.times do |j|
          thread = Thread.new do
            # For the example, +comparison.lookback+ will be +2+. On the first
            # loop, we want to go back 2 years, so the lookback will be +-2+ when
            # +j=0+. And +lookback=-1+ when +j=1+, etc
            lookback = -(comparison.lookback - j)

            # TODO Figure out the range for this query based on the composition
            # range, and the comparison properties
            b = binding

            compare_abs_from = abs_from.dup
            compare_abs_from = case comparison.period
            when :YoY
              compare_abs_from.advance(years: lookback)
            when :QoQ
              compare_abs_from.advance(months: 3 * lookback)
            when :WoW
              compare_abs_from.advance(weeks: lookback)
            end

            compare_abs_to = abs_to.dup
            compare_abs_to = case comparison.period
            when :YoY
              compare_abs_to.advance(years: lookback)
            when :QoQ
              compare_abs_to.advance(months: 3 * lookback)
            when :WoW
              compare_abs_to.advance(weeks: lookback)
            end

            b.local_variable_set(:compare_abs_from, compare_abs_from)
            b.local_variable_set(:compare_abs_to, compare_abs_to)

            job = BigQueryClient.instance.query_job(query(binding))
            compare_jobs << job

            b.local_variable_set(:compare_abs_from, compare_abs_from)
            b.local_variable_set(:compare_abs_to, compare_abs_to)
          end

          threads << thread
        end
      end

      threads.each(&:join)

      base_results = nil

      base_jobs.each do |job|
        job.wait_until_done!

        @big_query_total_bytes_billed += job.stats["query"]["totalBytesBilled"].to_i

        base_results = Results::TimeSeries.new(self, job.data)
        base_results.comparison_row_sets = []
        base_results.comparison_row_sets[0] = [] # TODO
      end

      compare_jobs.each do |job|
        job.wait_until_done!

        @big_query_total_bytes_billed += job.stats["query"]["totalBytesBilled"].to_i

        # TODO This should support an arbitrary number of comparisons, rather
        # than putting everything in [0], but currently the UI only allows only
        # a single comparison anyway, so we get away with it
        base_results.comparison_row_sets[0] << job.data
      end

      @results = base_results

      @results
    end

    private

    def comparisons_are_supported_granularity
      supported = {
        quarterly: [:YoY],
        monthly: [:YoY, :QoQ],
        daily: [:YoY, :QoQ, :WoW]
      }

      if granularity && comparisons.present?
        comparisons.each do |comparison|
          unless supported[granularity].include?(comparison.period)
            errors.add(:comparisons, "cannot use #{comparison.period} with #{granularity}")
          end
        end
      end
    end

    def rolling_must_have_window
      if granularity == :rolling && !window
        errors.add(:window, "is required with rolling")
      end
    end

    def window_only_supported_with_rolling
      if granularity != :rolling && window.present?
        errors.add(:window, "can only be used with rolling")
      end
    end

    def window_is_supported
      if window.present?
        errors.add(:window, "must be at least 2 days") if window < 2 * 86400
        # The app support windows as small as 1 second, so this could be
        # expanded if desired, but keeping it as whole days for now keeps the
        # UI simpler
        errors.add(:window, "must be a whole number of days") if window % 86400 != 0
      end
    end

    def each_comparions_is_valid
      (comparisons || []).each do |comparison|
        unless comparison.valid?
          comparison.errors.each do |e|
            # TODO Not sure which attribute to add these to yet
            errors.add("comparison.#{comparison.period}", e.full_message)
          end
        end
      end
    end

    def comparisons_are_unique
      # Each possible period (YoY, QoQ, etc), should only be used for one
      # comparison at a time. Using a period in more than one comparison would
      # just give duplicate results
      if comparisons.map(&:period).size != comparisons.map(&:period).uniq.size
        errors.add(:comparisons, "must use each period only once")
      end
    end

    def comparison_count_is_correct
      # The system supports any number of comparisons, but it's not super
      # practical to display more than one, so this limit is enforced
      if comparisons
        if comparisons.size > 1
          errors.add(:comparisons, "only support a single comparison")
        end
      end
    end

    ##
    # The period used for rolling uniques should always be longer than the
    # time series intervals' size. It wouldn't really make sense to show 7-day
    # uniques for monthly granularity

    def rolling_uniques_period_exceeds_interval
      metrics.each do |metric|
        if metric.metric == :rolling_uniques
          rolling_period = metric.variable

          interval_size = {
            daily: 86_400,
            weekly: 86_400 * 7,
            monthly: 86_400 * 31,
            quarterly: 86_400 * 31 * 3,
            yearly: 86_400 * 365,
            rolling: window
          }

          if rolling_period < interval_size[granularity]
            errors.add(:metrics, "cannot include rolling uniques with a period shorter than the selected granularity")
          end
        end
      end
    end
  end
end
