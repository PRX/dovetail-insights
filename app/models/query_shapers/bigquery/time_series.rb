module QueryShapers
  module Bigquery
    ##
    # Note that time series comparisons are achieved using multiple queries, so
    # there is no comparison-specific code in the query shaper.

    class TimeSeries < Dimensional
      # Map TimeSeriesComposition::GRANULARITY_OPTS to the BigQuery SQL version
      GRANULARITY_OPTS_MAP = {
        daily: "DAY",
        weekly: "WEEK(SUNDAY)",
        monthly: "MONTH",
        quarterly: "QUARTER",
        yearly: "YEAR"
      }

      def columns_for_table(table_name)
        columns = super

        # Time series queries require timestamps, even if no parameters would
        # otherwise, to be able to GROUP BY timestamp
        columns << "timestamp" if ["downloads", "impressions"].include?(table_name)

        columns.uniq
      end

      ##
      # tktk

      def selects
        selects = super

        if @composition.rolling?
          # Use the raw range tuple as the source of truth for GROUP BY, but include
          # the start of the range as a useful value we can use elsewhere to
          # represent each group
          selects << "rolling_window_range AS #{@composition.granularity_as}_raw"
          # All date/time group descriptors should use YYYY-MM-DDThh:mm:ssZ
          # Interval descriptors represent the beginning of the interval.
          selects << %(FORMAT_TIMESTAMP("%Y-%m-%dT%H:%M:%SZ", RANGE_START(rolling_window_range), "UTC") AS #{@composition.granularity_as})
        else
          granularity_arg = GRANULARITY_OPTS_MAP[@composition.granularity]

          # All date/time group descriptors should use YYYY-MM-DDThh:mm:ssZ
          # Interval descriptors represent the beginning of the interval
          selects << %(FORMAT_TIMESTAMP("%Y-%m-%dT%H:%M:%SZ", TIMESTAMP_TRUNC(downloads.timestamp, #{granularity_arg}), "UTC") AS #{@composition.granularity_as})
        end

        selects
      end

      ##
      # Time series have additional GROUP BY clauses for the granularity. For
      # calendar granularities, like daily/weekly/etc, one GROUP BY is added. With
      # +rolling+, an additional GROUP BY is added which is a field that contains
      # the ranges actually used to calculate the rolling windows. These ranges are
      # the source of truth, whereas the +granularity_as+ field is useful for
      # presentation, but is a less exact formatted version of the range.

      def group_bys
        group_bys = []

        group_bys << "#{@composition.granularity_as}_raw" if @composition.rolling?
        group_bys << @composition.granularity_as

        group_bys.concat(super)

        group_bys
      end
    end
  end
end
