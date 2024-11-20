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

      def self.from_params(params)
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
              # dimension name, so look it up if necessary.
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
              # TODO If the indicies are datetime string, we can't coerce them
              # to integers. Make sure we handle those properly, either by
              # looking at the type of the dimension for this group if it's
              # available, or heuristically from the indices if it's not
              group.indices = param_value.split(",").map { |i| i.strip.to_i }.sort
            end
          end
        end

        groups
      end

      attr_reader :dimension
      attr_accessor :truncate, :extract, :indices

      # TODO Validate that the dimension exists
      # TODO Validate that the options provided are supported by the dimension type
      # TODO Validate that the options don't conflict, even if they are all supported
      validates :dimension, presence: true

      def initialize(dimension_name)
        raise unless dimension_name.instance_of? Symbol

        @dimension = dimension_name
      end

      ##
      # When constructing parts of SQL queries related to this group or the
      # dimension for this group, we need a way to reference this particular
      # use of, for example, and column in a SELECT, as that column may appear
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

        (dimension_def["SummableMetrics"] || []).include?(metric.metric)
      end
    end
  end
end
