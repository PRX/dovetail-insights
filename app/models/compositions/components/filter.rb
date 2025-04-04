module Compositions
  module Components
    class Filter
      include ActiveModel::Model

      ##
      # Returns an array of **all** filters that are present in the given
      # params.
      #
      # This should attempt to construct +Filter+ instances as best as it can,
      # even if it's obvious that the params for some filter are missing or
      # invalid. We still want to capture as much of the user input as possible
      # so we can provide errors from validations and things like that.

      def self.all_from_params(params)
        # A filter for a single dimension may be defined across multiple params,
        # so we collect the filters in a hash with the dimension as keys, so
        # that as we find more params related to some filter, we can easily find
        # it and continue constructing the filter.
        filters = {}

        # Look at all the params, and find any that appear to be related to
        # filters. Build out +Filter+ instances based on all the available
        # configuration options present for each filter, even if they are in
        # separate params
        #
        # +params+ here is **all** params, not just filter params
        params.to_unsafe_h.each do |param_key, param_value|
          # Params for filters always begin with +filter.+
          match_data = param_key.match(/^filter\.([a-z_-]+)/)

          # If this is a filter param
          if match_data
            # Get the dimension this filter param is for. A lens composition
            # only ever has a single +Filter+ instance for any given dimension,
            # so all filter params for this dimension will apply to the same
            # +Filter+ instance.
            query_key = match_data[1]

            # The dimension key used in the params may be an alias for an
            # actual dimension defined in the schema. We want to use the true
            # dimension name, so look it up if necessary.
            #
            # For example, the QueryKey may be +podcast+ while the dimension
            # name is +podcast_id+.
            dimension_name = DataSchemaUtil.field_name_for_query_key(query_key)

            # Create a new filter for this dimension if we haven't seen it before
            filter = if filters.has_key? dimension_name
              filters[dimension_name]
            else
              filters[dimension_name] = new(dimension_name.to_sym)
            end

            # This param will possibly be one of several that, collectively,
            # define the entire filter. We determine which aspect of the filter
            # this param is defining by looking at the param key.
            #
            # Different parts of the filter definition may be handled in
            # different ways. For example, some param values may be split or
            # coerced into a specific data type before being applied to the
            # +Filter+ instance.
            if param_key.to_s == "filter.#{query_key}"
              filter.operator = param_value.to_sym
            elsif param_key.to_s == "filter.#{query_key}.values"
              filter.values = param_value.split(",").map { |v| v.strip }
            elsif param_key.to_s == "filter.#{query_key}.nulls"
              filter.nulls = param_value.to_sym
            elsif param_key.to_s == "filter.#{query_key}.from"
              filter.from = param_value.strip
            elsif param_key.to_s == "filter.#{query_key}.to"
              filter.to = param_value.strip
            elsif param_key.to_s == "filter.#{query_key}.gte"
              filter.gte = DurationShorthand.expand(param_value.strip)
            elsif param_key.to_s == "filter.#{query_key}.lt"
              filter.lt = DurationShorthand.expand(param_value.strip)
            elsif param_key.to_s == "filter.#{query_key}.extract"
              filter.extract = param_value.to_sym
            elsif param_key.to_s == "filter.#{query_key}.disabled"
              filter.disabled = true
            end
          end
        end

        # At this point, we only want to return the actual +Filter+ instances
        # from the hash.
        filters.values
      end

      include Ranging
      include Warnings

      attr_reader :dimension, :operator, :gte, :lt, :disabled
      attr_accessor :values, :extract, :nulls

      validates :dimension, :operator, presence: true
      validates :operator, inclusion: {in: [:include, :exclude], message: "must be either include or exclude"}
      validates :nulls, inclusion: {in: [:follow], message: "must be follow"}, if: -> { nulls }
      validate :dimension_is_defined, :uses_supported_options
      validate :token_filter_has_valid_values
      validate :timestamp_filter_only_uses_one_mode, :timestamp_filter_has_options, :timestamp_extraction_is_valid, :timestamp_range_is_complete
      validate :duration_has_range, :duration_range_is_complete, :gte_must_be_smaller_than_lt
      validate :nulls_follow_when_permitted

      def initialize(dimension_name)
        raise "Filter dimension must be a symbol" unless dimension_name.instance_of? Symbol

        @dimension = dimension_name
      end

      def operator=(operator)
        raise "Filter operator must be a symbol" unless operator.instance_of? Symbol

        @operator = operator
      end

      def gte=(gte)
        raise "Filter gte must be an integer" unless gte.instance_of? Integer

        @gte = gte
      end

      def lt=(lt)
        raise "Filter lt must be an integer" unless lt.instance_of? Integer

        @lt = lt
      end

      def as_json(options = {})
        obj = {dimension: dimension}

        obj[:operator] = operator if operator
        obj[:gte] = gte if gte
        obj[:lt] = lt if lt
        obj[:from] = from if from
        obj[:to] = to if to
        obj[:values] = values if values
        obj[:extract] = extract if extract

        obj
      end

      private

      def dimension_is_defined
        unless DataSchema.dimensions.has_key? dimension.to_s
          errors.add(:dimension, :invalid_dimension, message: "\"#{dimension}\" is not valid")
        end
      end

      ##
      # Various attributes of filters are allowed using allowlists. By default,
      # it's assumed that an attribute is not available for any particular
      # filter/dimension type. This only checks that an option _may_ be
      # supported by some filter, not that all options used in conjuction are
      # compatible – that's done in another validation.

      def uses_supported_options
        if DataSchema.dimensions.has_key? dimension.to_s
          dimension_data = DataSchemaUtil.field_definition(dimension)

          if nulls && !["Token"].include?(dimension_data["Type"])
            errors.add(:nulls, :invalid_option, message: "cannot be used with this filter")
          end

          if values && !["Token", "Timestamp"].include?(dimension_data["Type"])
            errors.add(:values, :invalid_option, message: "cannot be used with this filter")
          end

          if extract && !["Timestamp"].include?(dimension_data["Type"])
            errors.add(:extract, :invalid_option, message: "cannot be used with this filter")
          end

          if from && !["Timestamp"].include?(dimension_data["Type"])
            errors.add(:from, :invalid_option, message: "cannot be used with this filter")
          end

          if to && !["Timestamp"].include?(dimension_data["Type"])
            errors.add(:to, :invalid_option, message: "cannot be used with this filter")
          end

          if gte && !["Duration"].include?(dimension_data["Type"])
            errors.add(:gte, :invalid_option, message: "cannot be used with this filter")
          end

          if lt && !["Duration"].include?(dimension_data["Type"])
            errors.add(:lt, :invalid_option, message: "cannot be used with this filter")
          end
        end
      end

      ##
      # A filter for a Token dimension must have values. This is not true of
      # all filters that sometimes allow values.

      def token_filter_has_valid_values
        if DataSchema.dimensions.has_key? dimension.to_s
          dimension_data = DataSchemaUtil.field_definition(dimension)

          if dimension_data["Type"] == "Token"
            if values.blank?
              errors.add(:values, :missing_values, message: "are required")
            end
          end
        end
      end

      ##
      # Timestamp filters have multiple modes, which use different options.
      # Make sure that only options for one mode are in use at a time.

      def timestamp_filter_only_uses_one_mode
        if DataSchema.dimensions.has_key? dimension.to_s
          dimension_data = DataSchemaUtil.field_definition(dimension)

          if dimension_data["Type"] == "Timestamp"
            if (from || to) && extract
              errors.add(:extract, :invalid_option, message: "cannot be used with from or to")
            end

            if (from || to) && values
              errors.add(:values, :invalid_option, message: "cannot be used with from or to")
            end
          end
        end
      end

      def timestamp_filter_has_options
        if DataSchema.dimensions.has_key? dimension.to_s
          dimension_data = DataSchemaUtil.field_definition(dimension)

          if dimension_data["Type"] == "Timestamp"
            unless from || to || extract || values
              errors.add(:dimension, :invalid_option, message: "filter requires configuration")
            end
          end
        end
      end

      ##
      # If +extract+ is set, do some validations. This validation doesn't
      # determine if extract is compatible with other options, just that it's
      # valid in isolation as configured.

      def timestamp_extraction_is_valid
        if extract.present?
          # Only certain date parts are supported
          if ![:hour, :dow, :day, :week, :month, :year].include?(extract)
            errors.add(:extract, :bad_extract, message: "must be a supported value, not #{extract}")
          end

          # Extract always needs values
          if values.blank?
            errors.add(:values, :missing_values, message: "are required")
          end
        end
      end

      ##
      # If either +from+ to +to+ is present, both must be present

      def timestamp_range_is_complete
        if from || to
          errors.add(:from, :missing, message: "cannot be empty") if !from
          errors.add(:to, :missing, message: "cannot be empty") if !to
        end
      end

      def duration_has_range
        if DataSchema.dimensions.has_key? dimension.to_s
          dimension_data = DataSchemaUtil.field_definition(dimension)

          if dimension_data["Type"] == "Duration"
            errors.add(:gte, :missing_values, message: "are required") if !gte
            errors.add(:lt, :missing_values, message: "are required") if !lt
          end
        end
      end

      ##
      # If either +gte+ to +lt+ is present, both must be present

      def duration_range_is_complete
        if gte || lt
          errors.add(:gte, :missing, message: "cannot be empty") if !gte
          errors.add(:lt, :missing, message: "cannot be empty") if !lt
        end
      end

      def gte_must_be_smaller_than_lt
        errors.add(:gte, :out_of_order, message: "must precede lt") if gte && lt && gte >= lt
      end

      def nulls_follow_when_permitted
        if nulls == :follow
          if DataSchema.dimensions.has_key? dimension.to_s
            dimension_data = DataSchemaUtil.field_definition(dimension)

            unless dimension_data["PermitNulls"] == true
              errors.add(:nulls, :not_permitted, message: "are not allowed")
            end
          end
        end
      end
    end
  end
end
