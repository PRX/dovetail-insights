class RangeDescription
  def self.in_words(from, to)
    return unless from && to

    if Relatime::EXPRESSION_REGEXP.match?(from) && Relatime::EXPRESSION_REGEXP.match?(to)
      relatime_in_words(from, to)
    end
  end

  def self.relatime_in_words(from, to)
    unit_labels = {
      "m" => "minute",
      "h" => "hour",
      "D" => "day",
      "W" => "week",
      "X" => "week",
      "M" => "month",
      "Q" => "quarter",
      "Y" => "year"
    }

    from_match_data = from.match(Relatime::EXPRESSION_REGEXP)
    from_unit = from_match_data[2]
    from_offset = from_match_data[1]
    from_shift = from_match_data[3]

    to_match_data = to.match(Relatime::EXPRESSION_REGEXP)
    to_unit = to_match_data[2]
    to_offset = to_match_data[1]
    to_shift = to_match_data[3]

    # Handles cases where from and to use the same unit, and to is the
    # beginning of the current unit
    # e.g., now-1/M and now-1/M
    # e.g., now-10/M and now-1/M
    if !from_shift && !to_shift
      if from_offset.to_i < 0 && to_offset.to_i == -1
        if from_unit && from_unit == to_unit
          unit_label = unit_labels[from_unit]
          mag = from_offset.to_i.abs

          return "the previous#{(mag == 1) ? "" : " #{mag}"} #{unit_label.pluralize(mag)}"
        end
      end
    end

    # Cases where from and to are the same
    # e.g., now/h and now/h
    if !from_shift && !to_shift
      if from_offset.to_i == 0 && to_offset.to_i == 0
        if from_unit && from_unit == to_unit
          unit_label = unit_labels[from_unit]
          return "this #{unit_label}"
        end
      end
    end

    # Cases where from and to are the same
    # e.g., now/M and now
    if !from_shift && !to_shift
      if to_offset.to_i == 0 && from_offset.to_i == 0
        if from_unit && !to_unit
          unit_label = unit_labels[from_unit]
          return "this #{unit_label} so far"
        end
      end
    end

    # Cases where from and to are the same
    # e.g., now-48h and now
    if from_shift && !to_shift
      if !from_offset && !to_offset
        if !from_unit && !to_unit
          from_exp = from_shift.gsub("-", "_-").gsub("+", "_+")[1..]
          from_parts = from_exp.split("_")

          if from_parts.size == 1
            from_part_match_data = from_parts.first.match(/(([+-][0-9]+)([smhDM]))+/)

            from_shift_qty = from_part_match_data[2].to_i
            from_shift_unit = from_part_match_data[3]

            if from_shift_qty < 0
              return "#{from_shift_qty.abs} #{unit_labels[from_shift_unit].pluralize(mag)} ago to now"
            end
          end
        end
      end
    end

    "#{from} to #{to}"
  end
end
