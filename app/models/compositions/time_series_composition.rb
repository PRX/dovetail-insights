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
    GRANULARITY_OPTS = %i[daily weekly monthly quarterly yearly rolling]

    def self.query_value
      "timeSeries"
    end

    def self.from_params(params)
      composition = super

      composition.granularity = params[:granularity].to_sym if params[:granularity].present?
      composition.window = DurationShorthand.expand(params[:window]) if params[:window].present?

      composition.comparisons = Components::Comparison.all_from_params(params)

      composition
    end

    attr_reader :granularity, :window, :comparisons

    validates :granularity, presence: true
    validate :rolling_must_have_window, :window_only_supported_with_rolling, :window_is_supported
    validate :each_comparison_is_valid, :comparisons_are_unique, :comparison_count_is_correct
    validates :granularity, inclusion: {in: GRANULARITY_OPTS, message: "is not a supported value"}
    validate :comparisons_are_supported_granularity
    validate :rolling_uniques_period_exceeds_interval
    caution :first_interval_precedes_time_range, :last_interval_exceeds_time_range

    # TODO Validate metrics (may be different validations than with dimensional lens)

    def granularity=(granularity)
      raise unless granularity.instance_of? Symbol

      @granularity = granularity
    end

    def window=(window)
      raise unless window.instance_of? Integer

      @window = window
    end

    def granularity_as
      @granularity_as ||= ShortRandom.value(self)
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

      @query ||= begin
        shaper = QueryShapers::Bigquery::TimeSeries.new(self)

        # dimensional.sql.erb is suitable for both dimensional and time series
        # queries.
        erb = ERB.new(File.read(File.join(Rails.root, "app", "queries", "bigquery", "dimensional.sql.erb")))
        erb.result_with_hash(shaper.to_hash)
      end
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
      return unless valid?

      return @results if @results

      # Accumulate bytes for all query jobs
      @bigquery_total_bytes_billed = 0

      standard_jobs = [] # There will only be one of these, but easier to use an array
      compare_jobs = []
      threads = []

      # Start a query job for the standard query (this happens even when there
      # are no comparisons)
      threads << Thread.new do
        standard_jobs << BigqueryClient.instance.query_job(query(binding))
      end

      if comparisons.present?
        comparisons.each do |comparison|
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
              # loop, we want to go back 2 years, so the rewind will be +-2+ when
              # +j=0+. And +rewind=-1+ when +j=1+, etc
              rewind = -(comparison.lookback - j)

              b = binding

              compare_abs_from = abs_from.dup
              compare_abs_from = case comparison.period
              when :YoY
                compare_abs_from.advance(years: rewind)
              when :QoQ
                compare_abs_from.advance(months: 3 * rewind)
              when :WoW
                compare_abs_from.advance(weeks: rewind)
              end

              compare_abs_to = abs_to.dup
              compare_abs_to = case comparison.period
              when :YoY
                compare_abs_to.advance(years: rewind)
              when :QoQ
                compare_abs_to.advance(months: 3 * rewind)
              when :WoW
                compare_abs_to.advance(weeks: rewind)
              end

              b.local_variable_set(:compare_abs_from, compare_abs_from)
              b.local_variable_set(:compare_abs_to, compare_abs_to)

              job = BigqueryClient.instance.query_job(query(binding))

              # We need to be able to identify the results of this job later,
              # so we store some identifying metadata alongside it
              compare_jobs << {
                job: job,
                period: comparison.period,
                idx: j
              }

              b.local_variable_set(:compare_abs_from, abs_from)
              b.local_variable_set(:compare_abs_to, abs_to)
            end

            threads << thread
          end
        end
      end

      # Wait for each thread to finish _initiating_ the query jobs
      threads.each(&:join)

      # Load the standard query results in a Results instance
      standard_jobs.each do |job|
        job.wait_until_done!

        @bigquery_total_bytes_billed += job.stats["query"]["totalBytesBilled"].to_i
        @results = Results::TimeSeries.new(self, job.data)
      end

      # If there were any compare jobs, load their results into the Results
      # instance
      compare_jobs.each do |job|
        bigquery_job = job[:job]
        period = job[:period]
        idx = job[:idx]

        bigquery_job.wait_until_done!

        @bigquery_total_bytes_billed += bigquery_job.stats["query"]["totalBytesBilled"].to_i

        @results.comparison_results ||= {}
        @results.comparison_results[period] ||= []
        # Store the results of this comparison oldest-to-newest
        @results.comparison_results[period][idx] = bigquery_job.data
      end

      @results
    end

    def as_json(options = {})
      obj = super

      obj[:granularity] = granularity if granularity
      obj[:window] = window if window

      # TODO comparisons

      obj
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

    def each_comparison_is_valid
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

    def first_interval_precedes_time_range
      return unless abs_from && granularity

      # Create a Results just to get the interval descriptors from it
      results = Results::TimeSeries.new(self, nil)

      # The interval's descriptor is the beginning of the range covered by the
      # interval, so if it is before the composition's from, extends outside
      # the included data
      first_interval_start = Time.parse(results.unique_interval_descriptors.first)
      if first_interval_start < abs_from
        warnings.add(:from, :first_interval_out_of_range, message: "#{abs_from} does not cover all time included in the #{first_interval_start} interval, so it may include partial data")
      end
    end

    def last_interval_exceeds_time_range
      return unless abs_from && abs_to && granularity

      # Create a Results just to get the interval descriptors from it
      results = Results::TimeSeries.new(self, nil)

      # The interval's descriptor is the beginning of the range covered by the
      # interval. For the final interval, we want to check the *end* of the
      # range, so we advance the start time by some amount based on the chosen
      # granularity.
      last_interval_start = Time.parse(results.unique_interval_descriptors.last)

      # This is the **exclusive** end of the interval's range
      last_interval_end = case granularity
      when :daily
        last_interval_start.advance(days: 1)
      when :weekly
        last_interval_start.advance(weeks: 1)
      when :monthly
        last_interval_start.advance(months: 1)
      when :quarterly
        last_interval_start.advance(months: 3)
      when :yearly
        last_interval_start.advance(years: 1)
      when :rolling
        last_interval_start.advance(seconds: 1 * window) if window
      end

      # Both values here are **exclusive** range ends, so when they are equal
      # there is no overflow on the last interval. If the last interval end is
      # after the composition time range end, than it's covering a range that
      # exceeds the composition range.
      if last_interval_end > abs_to
        warnings.add(:to, :last_interval_out_of_range, message: "#{abs_to} does not cover all time included in the #{last_interval_start} interval, so it may include partial data")
      end
    end

    def range_includes_future
      # This is overriding the default message provided by DimensionalComposition
      warnings.add(:to, :includes_future, message: "extends into the future, so some intervals may include less data than you expect") if abs_to && abs_to > Time.now
    end
  end
end
