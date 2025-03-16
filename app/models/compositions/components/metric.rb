module Compositions
  module Components
    class Metric
      include ActiveModel::Model

      ##
      # Returns an array of **all** metrics that are present in the given params.
      #
      # This should attempt to construct +Metric+ instances as best as it can,
      # even if it's obvious that the params for some metric are missing or
      # invalid. We still want to capture as much of the user input as possible
      # so we can provide errors from validations and things like that.

      def self.all_from_params(params)
        # All metrics are listed in the value of a single param called
        # +metrics+, and are separated by commas.

        return [] if !params[:metrics]

        params[:metrics].split(",").map do |metric_param_part|
          # Metric names in the schema look like foo(bar) or count(downloads).
          # In the URL, metrics may be expressed exactly by name, or with
          # variables, like foo(bar,1,2). This removes the variable part,
          # leaving just the schema name.
          metric_name = metric_param_part.gsub(/([a-zA-Z_]+\([a-zA-Z_]+)(,.*)+(\))/) { |match| "#{$1}#{$3}" }

          metric = new(metric_name.to_sym)

          # TODO
          # Some metrics include a variable, which will appear in the value
          # after the name, enclosed in parens
          # metric_variable_match_data = metric_param_part.match(/\(([0-9]+)\)/)
          # if metric_variable_match_data
          #   metric.variable = metric_variable_match_data[1].to_i
          # end

          metric
        end
      end

      include Warnings

      # TODO Validate that variable metrics have values
      # TODO Validate variable values
      # TODO Validate metric allows variable

      attr_reader :metric, :variable

      validate :metric_is_defined

      def initialize(metric)
        raise "Metric must be a symbol" unless metric.instance_of? Symbol

        @metric = metric
      end

      def variable=(variable)
        # TODO This value should be in seconds, and should support both raw input
        # in seconds from the form, and more friendly input like "7D" and convert
        # the days to seconds
        raise "Metric variable must " unless variable.instance_of? Integer

        @variable = variable
      end

      ##
      # When constructing parts of SQL queries related to this metric, we need a
      # way to reference this particular
      # use of, for example, a column in a SELECT, as that column may appear
      # in the query more than once, for different reasons. This generates an
      # opaque value that we use as that reference anywhere it's needed in the
      # query, rather than just a metric name or something like that.

      def as
        @as ||= :"#{metric.to_s.tr("(", "_").tr(")", "_")}_#{ShortRandom.value(self)}"
      end

      def as_json(options = {})
        obj = {metric: metric}

        obj[:variable] = variable if variable

        obj
      end

      private

      def metric_is_defined
        unless DataSchema.metrics.has_key? metric.to_s
          errors.add(:metric, "#{metric} is not a valid metric")
        end
      end
    end
  end
end
