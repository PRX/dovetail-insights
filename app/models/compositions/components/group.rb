module Compositions
  module Components
    class Group
      include ActiveModel::Model

      ##
      # Returns an array of **all** groups that are present in the given params.
      #
      # This should attempt to construct +Group+ instances as best as it can,
      # even if it's obvious that the params for some group are missing or
      # invalid. We still want to capture as much of the user input as possible
      # so we can provide errors from validations and things like that.

      def self.all_from_params(params)
        # A group for a single dimension may be defined across multiple params,
        # so we collect the groups in an array. The position in the array is
        # based on the position indicated in the params. For example, a param
        # for +group.1+ indicates it should be treated as the _first_ group for
        # the composition, so it is the first element in the array.
        groups = []

        # Look at all the params, and find any that appear to be related to
        # groups. Build out +Group+ instances based on all the available
        # configuration options present for each group, even if they are in
        # separate params
        params.to_unsafe_h.each do |param_key, param_value|
          # Params for groups always begin with +group.+
          match_data = param_key.match(/^group\.([0-9]+)/)

          # If this is a group param
          if match_data
            group_number = match_data[1]
            group_index = match_data[1].to_i - 1

            # Create a new group for this position if we haven't seen it before
            group = if groups[group_index]
              groups[group_index]
            else
              # The dimension key used in the params may be an alias for an
              # actual dimension defined in the schema. We want to use the true
              # dimension name, so look it up if necessary. If there's no match,
              # use the key as given.
              dimension_name = DataSchema.dimensions.find { |k, v| v["QueryKey"] == param_value }&.dig(0) || param_value

              groups[group_index] = new(dimension_name.to_sym)
            end

            # This param will possibly be one of several that, collectively,
            # define the entire group. We determine which aspect of the group
            # this param is defining by looking at the param key.
            #
            # Different parts of the group definition may be handled in
            # different ways. For example, some param values may be split or
            # coerced into a specific data type before being applied to the
            # +Group+ instance.

            if param_key == "group.#{group_number}.extract"
              group.extract = param_value
            elsif param_key == "group.#{group_number}.truncate"
              group.truncate = param_value
            elsif param_key == "group.#{group_number}.indices"
              # +indicies+ are used when grouping by ranges. This is supported
              # for both Timestamp and Duration dimensions. With Timestamp
              # dimensions, each index is a time (e.g., YYYY-MM-DDTHH:MM:SSZ),
              # and with Duration dimensions, each index is a number (of
              # seconds) like 86400 or a shorthand like "7D", which should be
              # expanded into seconds.
              raw_values = param_value.split(",", -1).map { |i| i.strip }
              group.indices = raw_values.map do |v|
                if /^[0-9]{4}-[0-9]{1,2}/.match?(v)
                  # TODO
                  v
                elsif /^[0-9]+[a-zA-Z]$/.match?(v)
                  DurationShorthand.expand(v)
                else
                  v.present? ? v.to_i : nil
                end
              end
            end
          end
        end

        # We may end up with zero or more groups in this array being returned
        groups
      end

      attr_reader :dimension
      attr_accessor :truncate, :extract, :indices

      # TODO Validate that the dimension exists
      # TODO Validate that the options provided are supported by the dimension type
      # TODO Validate that the options don't conflict, even if they are all supported
      # TODO Validate that the values for an option (like extract or truncate) are valid
      # TODO Validate indices are valid for dimension type
      validates :dimension, presence: true
      validate :dimension_is_real
      validate :no_missing_indices, :indices_order_is_correct

      def initialize(dimension_name)
        raise unless dimension_name.instance_of? Symbol

        @dimension = dimension_name
      end

      ##
      # When constructing parts of SQL queries related to this group or the
      # dimension for this group, we need a way to reference this particular
      # use of, for example, a column in a SELECT, as that column may appear
      # in the query more than once, for different reasons. This generates an
      # opaque value that we use as that reference anywhere it's needed in the
      # query, rather than just a dimension name or something like that.

      def as
        @as ||= Base64.strict_encode64(SecureRandom.uuid).to_sym
      end

      ##
      # Returns true if the data schema allows the given metric to be summed
      # for the dimension of this group.

      def summable?(metric)
        dimension_def = DataSchema.dimensions[dimension.to_s]

        (dimension_def["SummableMetrics"] || []).include?(metric.metric.to_s)
      end

      private

      def dimension_is_real
        unless DataSchema.dimensions.keys.include?(dimension.to_s)
          errors.add(:dimension, :invalid, message: "#{dimension} is not a valid group dimension")
        end
      end

      def no_missing_indices
        if indices && indices.empty?
          errors.add(:indices, :missing_indices, message: "cannot be empty")
        end

        if indices&.any? { |i| i.nil? }
          errors.add(:indices, :missing_indices, message: "cannot include empty values")
        end
      end

      def indices_order_is_correct
        if indices && indices != indices.compact.sort
          errors.add(:indices, :out_of_order, message: "must be in increasing order")
        end
      end
    end
  end
end
