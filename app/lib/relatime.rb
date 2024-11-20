class RelativeExpressionError < StandardError
end

class Relatime
  EXPRESSION_REGEXP = /^now(?:(?:([-+][0-9]+)[mhDWXMQY]?)?\/([mhDWXMQY]))?((?:[+-][0-9]+[smhDM])+)?$/

  ##
  # Takes a specially-crafted relative time _expression_ and converts it to the
  # correct absolute time, relative to now (or a provide DateTime).
  #
  # The absolute time is calculated differently, given the same expression,
  # depending on whether it is being used for the beginning or end of a time
  # range. This allows for more intuitive expression syntax for the most basic
  # and common use cases.
  #
  # An expression looks something like "now", "now/Y", or "now-3/M+12h".
  #
  # Every expressions starts with "now". When no qualifiers are added, this
  # resolves to the current date and time (regardless of which end of the time
  # range the expression is being used for).
  #
  # Adding a slash and an option alters the expression to return the beginning of
  # the current specific unit of time. For example, "now/Y" returns the start of
  # the current year (like 2024-01-01 00:00:00), and "now/M" returns the start of
  # the current month (like 2024-05-01 00:00:00).
  # Available: m, h, D, W, X, M, Q, Y
  # W and X indicate whether weeks are considered to be begin on Sunday (W) or
  # Monday (X).
  #
  # To move away from the current period, an offset can be given. "now-1Y/Y"
  # resolves to the start of last year, and "now-2Y/Y" resolves to the start of
  # the year before that. These expressions can be shortend to "now-1/Y" and
  # "now-2/Y". The number in the offset must be signed integer, and positive
  # values must start with a plus sign
  #
  # When an expression with a slash is used for the end of the time range, it
  # resolves to the _next_ specified unit, as compared to what was just described.
  # For example, "now-1/Y" resolve to the beginning of the current year (rather
  # than the beginning of the previous year). This allows for a user to define a
  # range like "now/Y to now/Y", to cover the entire current year, rather than
  # needing to do the math to offset the end expression.
  #
  # Additionally, further qualifiers can be added to the end of the expression to
  # adjust the resolved value a specific amount of time. For example "now/Y+12h"
  # resolves to 12 hours after the beginning of the current year. "now/Y+1M-12h"
  # means, "go to the beginning of the current year, then move ahead by 1 month,
  # then move back by 12 hours" (so, 2024-01-31 12:00:00, or similar).
  # Available: s, m, h, D, M
  #
  # Note that when an expression is being resolved for the end of a time range,
  # the automatic offset to the next specific unit happens before any
  # adjustments. For example, "now-1/X" as the start of range may resolve to
  # the beginning of Monday October 14th. And "now-1/X" as the end of a range
  # would resolve to the beginning of Monday October 21st. Therefore, you could
  # **not** use "now-1/X+2D" to create a range that begins on the 14th and ends
  # two days later, since "now-1/X" as the range end is already more than 2 days
  # later. You would have to either subtract from "now-1/X", or use "now-2/X"
  # and add.
  #
  # To highlight a point: "now-1/X" as the start of a range is equal to
  # "now-2/X" as the end of a range.
  #
  # Adjustments are applied in the order listed, so "now/Y+2M-12h-1M" goes to the
  # beginning of the year, moves ahead 2 months (to the beginning of March), then
  # moves back 12 hours (to noon on February 29th), then moves back 1 month, to
  # resolve to noon on January 29. Reordering the expression to "now/Y+2M-1M-12h"
  # would, instead, end at noon on January 31. This is by design.
  #
  # Note that each adjustment may do some clamping. For example, if it is
  # currently March 31st, "now-1M" resolves to February 28th, as the month
  # adjustment is ensuring that the result will be in February, and there is
  # never a February 31st. So "now-1M-1M" would resolve to January 28th, since
  # the first adjustment is clamped, while "now-2M" would resolve to January
  # 31st, since no clamping is required when moving directly from March to
  # January.
  #
  # Examples
  #     Start                 End                  Description
  #     now/M                 now/M                The entire current calendar month
  #     now/M                 now                  The calendar month so far
  #     now/Y                 now                  The current calendar year so far
  #     now-30m               now                  The last 30 minutes
  #     now-1/M               now-1/M              The previous full calendar month
  #     now-1/X               now-1/X-2D           Monday through Friday of the previous week, where weeks start on Monday
  #     now-1/W+1D            now-1/W-1D           Monday through Friday of the previous week, where weeks start on Sunday
  #     now-1/M+4D            now-2/M+15D          The 5th through the 15th of the previous month
  #     now-1/M+4D+12h        now-2/M+15D+12h      The 5th through the 15th of the previous month, starting and ending at noon
  #     now-100/h             now-1/h              The previous 100 hours, not including the current hour (100 total hours)
  #     now-99/h              now/h                The previous 99 hours and the current hour (100 total hours)
  #     now-3/M               now+3/M              The 3 previous calendar months, the current month, and the next three calendar months
  #     now/Y                 now-1/M              Beginning of the current calendar year to now, excluding the current calendar day
  #
  # All calculations are based in UTC.
  #
  # Returns a DateTime
  def self.rel2abs(expression = "now", side = :front, now = DateTime.now.new_offset(0))
    abs = now

    match_data = expression.match(EXPRESSION_REGEXP)

    if !match_data
      raise RelativeExpressionError.new "Invalid expression"
    end

    if match_data
      unit = match_data[2]
      offset = match_data[1]
      shift = match_data[3]

      # If there is a unit, like /M or /Y, go to the beginning of the current
      # specified unit, like the beginning of the current month or current year.
      if unit
        abs = case unit
        when "m"
          abs.change(sec: 0)
        when "h"
          abs.change(min: 0)
        when "D"
          abs.change(hour: 0)
        when "W"
          abs.beginning_of_week(:sunday).change(hour: 0)
        when "X"
          abs.beginning_of_week(:monday).change(hour: 0)
        when "M"
          abs.change(day: 1, hour: 0)
        when "Q"
          abs.beginning_of_quarter.change(hour: 0)
        when "Y"
          abs.change(month: 1, day: 1, hour: 0)
        end
      end

      if unit
        # Default to a 0 offset for the unit, or use the given offset
        adjusted_offset = offset ? offset.to_i : 0
        # If this is for the end of the range, we actually want the beginning of
        # the next specific unit. E.g., now/Y should be midnight 1 Jan of next
        # year, so add 1 to whatever offset was provided
        adjusted_offset += 1 if side == :back

        abs = case unit
        when "m"
          abs.advance(minutes: adjusted_offset)
        when "h"
          abs.advance(hours: adjusted_offset)
        when "D"
          abs.advance(days: adjusted_offset)
        when "W"
          # when unit==W, we're already always at a natural week boundary, so
          # we can move in 7-day chunks
          abs.advance(days: adjusted_offset * 7)
        when "X"
          # when unit==X, we're already always at a natural week boundary, so
          # we can move in 7-day chunks
          abs.advance(days: adjusted_offset * 7)
        when "M"
          abs.advance(months: adjusted_offset)
        when "Q"
          # when unit==Q, we're already always at a natural quarter boundary, so
          # we can move in 3-month chunks
          abs.advance(months: adjusted_offset * 3)
        when "Y"
          abs.advance(years: adjusted_offset)
        end
      end

      # shift will look like "+15D+12h" or "-2Y"
      if shift
        # We want to split shift into individual components, so an underscore
        # is added before any plus or hyphen, and then we split on underscores.
        # Sort of a hack.
        exp = shift.gsub("-", "_-").gsub("+", "_+")[1..]
        parts = exp.split("_")

        # Parts will be like ["+15D", "+12h"]
        parts.each do |part|
          part_match_data = part.match(/(([+-][0-9]+)([smhDM]))+/)

          qty = part_match_data[2]
          unt = part_match_data[3]

          abs = case unt
          when "s"
            abs.advance(seconds: qty.to_i)
          when "m"
            abs.advance(minutes: qty.to_i)
          when "h"
            abs.advance(hours: qty.to_i)
          when "D"
            abs.advance(days: qty.to_i)
          when "M"
            abs.advance(months: qty.to_i)
          end
        end
      end
    end

    abs
  end
end
