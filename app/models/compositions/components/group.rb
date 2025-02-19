module Compositions
  module Components
    class Group
      # When changing these, be sure to also change the view helpers that
      # transform these values into database engine specific arguments.
      #
      # In BigQuery, DAYOFWEEK returns values 1-7, 1=Sunday
      EXTRACT_OPTS = %i[hour day_of_week day week month year]
      TRUNCATE_OPTS = %i[week month year]

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
              group.extract = param_value.to_sym
            elsif param_key == "group.#{group_number}.truncate"
              group.truncate = param_value.to_sym
            elsif param_key == "group.#{group_number}.indices"
              # +indicies+ are used when grouping by ranges. This is supported
              # for both Timestamp and Duration dimensions. With Timestamp
              # dimensions, each index is a time (e.g., YYYY-MM-DD or
              # YYYY-MM-DDTHH:MM:SSZ) or a relatime expression (e.g., now/Y),
              # and with Duration dimensions, each index is a number (of
              # seconds) like 86400 or a shorthand like "7D", which should be
              # expanded into seconds.
              raw_values = param_value.split(",", -1).map { |i| i.strip }
              group.indices = raw_values.map do |v|
                if /^[0-9]{4}-[0-9]{2}/.match?(v)
                  # Anything that looks like a date, keep as-is
                  v
                elsif Relatime::EXPRESSION_REGEXP.match?(v)
                  # Anything that looks like a relatime expression keep as-is
                  v
                elsif /^[0-9]+[a-zA-Z]$/.match?(v)
                  # If it looks like a duration shorthand, expand it to seconds
                  DurationShorthand.expand(v)
                elsif /^[0-9]+$/.match?(v)
                  # If it looks like an integer, assume it's seconds and cast
                  # to integer
                  v.to_i
                else
                  # Everything else keep as is; validations will catch any
                  # issues with these strings
                  v.present? ? v : nil
                end
              end
            end
          end
        end

        # We may end up with zero or more groups in this array being returned
        groups
      end

      include Warnings

      attr_reader :dimension
      attr_accessor :truncate, :extract, :indices

      validates :dimension, presence: true
      validate :dimension_is_real
      validate :no_missing_indices, :indices_order_is_correct, :indices_are_not_repeated
      validate :timestamp_indices_are_valid, :duration_indices_are_valid
      validates :extract, inclusion: {in: EXTRACT_OPTS, message: "by %{value} is not a supported operation"}, if: -> { extract }
      validates :truncate, inclusion: {in: TRUNCATE_OPTS, message: "by %{value} is not a supported operation"}, if: -> { truncate }
      validate :no_options_for_token_type
      validate :duration_type_has_only_indices
      validate :timestamp_type_has_single_option
      caution :local_time_distortion

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

      ##
      # Returns an array of the current indicies, where any values in the set
      # that appear to be relatime expressions have been resolved to their
      # current absolute time

      def abs_indices
        indices&.map do |i|
          if i.to_s.match Relatime::EXPRESSION_REGEXP
            Relatime.rel2abs(i.to_s, :front, DateTime.now.new_offset(0))
          else
            i
          end
        end
      end

      private

      def dimension_is_real
        unless DataSchema.dimensions.key?(dimension.to_s)
          errors.add(:dimension, :invalid, message: "#{dimension} is not a valid group dimension")
        end
      end

      ##
      # Dimensions with a Token type don't support any group options

      def no_options_for_token_type
        dimension_def = DataSchema.dimensions[dimension.to_s]

        if dimension_def && dimension_def["Type"] == "Token"
          errors.add(:extract, :option_mismatch, message: "option is not valid with dimenson #{dimension}") if extract
          errors.add(:truncate, :option_mismatch, message: "option is not valid with dimenson #{dimension}") if truncate
          errors.add(:indices, :option_mismatch, message: "option is not valid with dimenson #{dimension}") if indices
        end
      end

      ##
      # Dimensions with a Duration type don't support any group options besides
      # indices, and that option is required

      def duration_type_has_only_indices
        dimension_def = DataSchema.dimensions[dimension.to_s]

        if dimension_def && dimension_def["Type"] == "Duration"
          errors.add(:indices, :option_mismatch, message: "are required with dimenson #{dimension}") unless indices
          errors.add(:extract, :option_mismatch, message: "option is not valid with dimenson #{dimension}") if extract
          errors.add(:truncate, :option_mismatch, message: "option is not valid with dimenson #{dimension}") if truncate
        end
      end

      ##
      # Dimensions with a Timestamp type support several group options, but
      # only one can be used at a time.

      def timestamp_type_has_single_option
        dimension_def = DataSchema.dimensions[dimension.to_s]

        if dimension_def && dimension_def["Type"] == "Timestamp"
          errors.add(:extract, :option_conflict, message: "option cannot be used with other options") if extract && (truncate || indices)
          errors.add(:truncate, :option_conflict, message: "option cannot be used with other options") if truncate && (extract || indices)
          errors.add(:indices, :option_conflict, message: "option cannot be used with other options") if indices && (extract || truncate)
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
        if abs_indices && abs_indices != abs_indices.compact.sort
          errors.add(:indices, :out_of_order, message: "must be in increasing order")
        end
      end

      def indices_are_not_repeated
        if indices && abs_indices.uniq.length != abs_indices.length
          errors.add(:indices, :duplicates, message: "cannot contain duplicates")
        end
      end

      def duration_indices_are_valid
        dimension_def = DataSchema.dimensions[dimension.to_s]

        if dimension_def && dimension_def["Type"] == "Duration" && indices
          indices.each do |i|
            if i.is_a?(Integer)
            elsif /^[0-9]+[a-zA-Z]$/.match?(i)
            else
              errors.add(:indices, :invalid, message: "#{i} is not a valid index")
            end
          end
        end
      end

      def timestamp_indices_are_valid
        dimension_def = DataSchema.dimensions[dimension.to_s]

        if dimension_def && dimension_def["Type"] == "Timestamp" && indices
          indices.each do |i|
            if !i.is_a?(String)
              errors.add(:indices, :invalid, message: "#{i} is not a valid index")
            elsif i.match Relatime::EXPRESSION_REGEXP
            elsif i.match?(/^\d{4}-[01]\d-[0-3]\d$/)
            elsif i.match?(/^\d{4}-[01]\d-[0-3]\dT[0-2]\d:[0-5]\d:[0-5]\dZ$/)
            else
              errors.add(:indices, :invalid, message: "#{i} is not a valid index")
            end
          end
        end
      end

      def local_time_distortion
        warnings.add(:dimension, :distortion, message: "creates data groupings that may not reflect reality") if dimension == :download_local_timestamp
      end
    end
  end
end
