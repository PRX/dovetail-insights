module Compositions
  module Components
    class Comparison
      include ActiveModel::Model

      POP_COMPARISON_OPTS = %i[WoW QoQ YoY]

      ##
      # Returns an array of **all** comparisons that are present in the given
      # params.
      #
      # This should attempt to construct +Comparison+ instances as best as it can,
      # even if it's obvious that the params for some comparison are missing or
      # invalid. We still want to capture as much of the user input as possible
      # so we can provide errors from validations and things like that.

      def self.all_from_params(params)
        # Each comparison params starts with +compare.+
        compare_params = params.to_unsafe_h.filter { |k, v| k.match(/^compare\..+/) }

        # Each compare param looks like: +compare.XoX=3+, where +XoX+ is something
        # like YoY or QoQ, representing a year-over-year or quarter-over-quarter
        # comparison, and the value is the number of years/quaters/etc to include
        # in the comparison.
        compare_params.map do |param_key, param_value|
          new(param_key.split(".")[1].to_sym, param_value.to_i)
        end
      end

      include Warnings

      attr_reader :period, :lookback

      validate :period_is_supported, :lookback_is_supported

      def initialize(period, lookback)
        raise unless period.instance_of? Symbol
        raise unless lookback.instance_of? Integer

        @period = period
        @lookback = lookback
      end

      private

      def period_is_supported
        unless POP_COMPARISON_OPTS.include? period
          errors.add(:comparison, "#{period} is not a valid comparison")
        end
      end

      def lookback_is_supported
        unless lookback > 0 && lookback < 5
          errors.add(:comparison, "#{period} comparison lookback must be between 0 and 5, but was #{lookback}")
        end
      end
    end
  end
end
