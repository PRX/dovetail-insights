module Results
  class Cume < TimeSeries
    def get_cume_value(metric, interval_descriptor, group_1_member_descriptor = false, group_2_member_descriptor = false)
      @cume_value_cache ||= {}
      cache_key = [metric.metric, interval_descriptor, group_1_member_descriptor, group_2_member_descriptor]

      # Return memoized value even if it's nil
      @cume_value_cache[cache_key] if @cume_value_cache.key?(cache_key)

      if unique_interval_descriptors.first == interval_descriptor
        @cume_value_cache[cache_key] = get_value(metric, interval_descriptor, group_1_member_descriptor, group_2_member_descriptor) || 0
      else
        idx = unique_interval_descriptors.index(interval_descriptor)
        previous_idx = idx - 1
        previous_interval_descriptor = unique_interval_descriptors[previous_idx]

        previous_cume = get_cume_value(metric, previous_interval_descriptor, group_1_member_descriptor, group_2_member_descriptor)

        cur_value = get_value(metric, interval_descriptor, group_1_member_descriptor, group_2_member_descriptor) || 0
        new_cume = previous_cume + cur_value

        @cume_value_cache[cache_key] = new_cume
      end

      @cume_value_cache[cache_key]
    end
  end
end
