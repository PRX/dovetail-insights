class RangeDescription
  def self.in_words(from, to)
    return unless from && to

    if Relatime::EXPRESSION_REGEXP.match?(from) && Relatime::EXPRESSION_REGEXP.match?(to)
      relatime_in_words(from, to)
    elsif Relatime::EXPRESSION_REGEXP.match?(from)
      # Only from is relatime
    elsif Relatime::EXPRESSION_REGEXP.match?(to)
      # Only to is relatime
    else
      timestamps_in_words(from, to)
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

  def self.timestamps_in_words(from, to)
    from_time = DateTime.parse(from)
    to_time = DateTime.parse(to)

    # e.g., 2020-01-01 to 2021-01-01 aka 2020
    # e.g., 2020-01-01 to 2023-01-01 aka 2020-2022
    if from_time == from_time.beginning_of_year && to_time == to_time.beginning_of_year
      years = to_time.year - from_time.year
      if years == 1
        return from_time.year.to_s
      else
        return "#{from_time.year}–#{to_time.year - 1}"
      end
    end

    # Single complete month
    # e.g., 2020-01-01 to 2020-02-1 aka January 2020
    if from_time == from_time.beginning_of_month && to_time == to_time.beginning_of_month
      years_dif = to_time.year - from_time.year
      months_dif = to_time.month - from_time.month
      if years_dif == 0 && months_dif == 1
        return "#{Date::ABBR_MONTHNAMES[from_time.month]} #{from_time.year}"
      end
    end

    # Multiple complete months
    # e.g., 2019-12-01 to 2020-02-01 aka Dec 2019 to Jan 2020
    if from_time == from_time.beginning_of_month && to_time == to_time.beginning_of_month
      final_momth = to_time.advance(months: -1)
      return "#{Date::ABBR_MONTHNAMES[from_time.month]} #{from_time.year}—#{Date::ABBR_MONTHNAMES[final_momth.month]} #{final_momth.year}"
    end

    "#{from_time} to #{to_time}"
  end
end
