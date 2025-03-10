module Results
  class Cume < TimeSeries
    include GroupableResults

    ##
    # Return an array of descriptors for all windows within the selected range.
    # Each of these descriptors represents the start of the window, so if
    # windows are 24 hours long, `0` represents the first 24 hours, 86_400
    # is the next 24 hours, etc.
    #
    # The way these are calculated must match how the windows are calculated in
    # the SQL query.
    #
    # These are integers.

    def unique_window_descriptors
      return @unique_window_descriptors if @unique_window_descriptors

      if composition.abs_from && composition.abs_to
        range_duration_in_seconds = composition.abs_to.to_time - composition.abs_from.to_time
        num_windows_in_range = (range_duration_in_seconds / composition.window) - 1
        rounded_num_windows_in_range = num_windows_in_range.floor

        @unique_interval_descriptors = rounded_num_windows_in_range.times.map do |i|
          i * composition.window
        end
      end
    end

    ##
    # Lookup the raw data point for a set of parameters. This is **not the
    # cumulative value** for the given window.

    def lookup_data_point(metric, window_descriptor, group_1_member_descriptor = false, group_2_member_descriptor = false)
      @lookup_data_point_cache ||= {}
      cache_key = [metric, window_descriptor, group_1_member_descriptor, group_2_member_descriptor]

      # Return memoized value even if it's nil
      return @lookup_data_point_cache[cache_key] if @lookup_data_point_cache.key?(cache_key)

      row = rows.find do |row|
        window_test = row[:cume_window_range_start] == window_descriptor

        g1_test = true
        g2_test = true

        g1_test = row[composition.groups[0].as] == group_1_member_descriptor if group_1_member_descriptor && composition.groups[0]
        g2_test = row[composition.groups[1].as] == group_2_member_descriptor if group_2_member_descriptor && composition.groups[1]

        g1_test = row[composition.groups[0].as].nil? if group_1_member_descriptor.nil? && composition.groups[0]
        g2_test = row[composition.groups[1].as].nil? if group_2_member_descriptor.nil? && composition.groups[1]

        window_test && g1_test && g2_test
      end

      # If a row was found, return the value from that row for the given metric.
      # Currently, this returns +nil+ if no value was found. It does **not**
      # default to a value like +0+.
      @lookup_data_point_cache[cache_key] = row && row[metric.as]
    end

    ##
    # Lookup the cumulative value for the parameters, based on the previous
    # values in the series.

    def lookup_cume_data_point(metric, window_descriptor, group_1_member_descriptor = false, group_2_member_descriptor = false)
      @cume_value_cache ||= {}
      cache_key = [metric, window_descriptor, group_1_member_descriptor, group_2_member_descriptor]

      # Return memoized value even if it's nil
      @cume_value_cache[cache_key] if @cume_value_cache.key?(cache_key)

      if unique_window_descriptors.first == window_descriptor
        @cume_value_cache[cache_key] = lookup_data_point(metric, window_descriptor, group_1_member_descriptor, group_2_member_descriptor) || 0
      else
        episode_age = group_member_descriptor_for_field(@composition.groups[0], group_1_member_descriptor, :current_episode_age_in_seconds, :cume)
        episode_pub_time_str = group_member_descriptor_for_field(@composition.groups[0], group_1_member_descriptor, :episode_publish_timestamp, :cume)

        return if window_descriptor > episode_age
        return if Time.parse(episode_pub_time_str) + window_descriptor.to_i > composition.abs_to

        idx = unique_window_descriptors.index(window_descriptor)
        previous_idx = idx - 1
        previous_window_descriptor = unique_window_descriptors[previous_idx]

        previous_cume = lookup_cume_data_point(metric, previous_window_descriptor, group_1_member_descriptor, group_2_member_descriptor)

        cur_value = lookup_data_point(metric, window_descriptor, group_1_member_descriptor, group_2_member_descriptor) || 0
        new_cume = previous_cume + cur_value

        @cume_value_cache[cache_key] = new_cume
      end
    end
  end
end
