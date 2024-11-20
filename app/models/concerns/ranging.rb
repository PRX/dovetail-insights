##
# Provides standard behavior for things that have a operating range. Expects
# +from+ and +to+ to be set, and expects +abs_from+ and +abs_to+ to be used as
# the output range. Handles some validations, and resolving +from+ to
# +abs_from+ in a standard way (same with +to+).

module Ranging
  extend ActiveSupport::Concern

  included do
    # +from+ and +to+ are always strings, and can represent either absolute or
    # relative dates or times. See +#abs_from+ and +#abs_to+ if you're looking
    # for +DateTime+ instances for these values.
    attr_reader :from, :to

    validate :from_must_precede_to

    # All classes that implement Ranging _support_ from and to, but not all of
    # them _require_ from and to. Those that do require them should validate
    # their presence in the class.

    # Check for valid absolute date or time or relative expression for from and to
    validates_each :from, :to do |record, attr, value|
      if value
        if value.match Relatime::EXPRESSION_REGEXP
        elsif value.match?(/^\d{4}-[01]\d-[0-3]\d$/)
        elsif value.match?(/^\d{4}-[01]\d-[0-3]\dT[0-2]\d:[0-5]\d:[0-5]\dZ$/)
        elsif value.match?(/^\d/)
          # If the input starts with any digit, treat it as a date or time. If we
          # got here, it wasn't a date or time in a format that we were expecting
          record.errors.add attr, :invalid_date, message: "has invalid date"
        else
          # If the input doesn't start with a number, treat it as a relative
          # expression. If we got here, it wasn't an expression that followed the
          # required format
          record.errors.add attr, :invalid_expression, message: "has invalid relative expression"
        end
      end
    end

    ##
    # Returns a +DateTime+ for the string value in +from+.

    def abs_from
      resolve_to_abs(from, :front)
    end

    ##
    # Returns a +DateTime+ for the string value in +to+.

    def abs_to
      resolve_to_abs(to, :back)
    end

    ##
    # Relative time expressions can include literal plus signs (like
    # "now/Y+5D"). We want those expressions to appear like that in the URL
    # query but, by default, a literal plus needs to be encoded, since a plus in
    # a query represents a space. So by the time the value gets here, if it had a
    # space in the URL query, it will be a space in `from`. So it's a bit of a
    # hack, but we turn any spaces in `from` back into literal plus signs.
    #
    # For example, a URL including +?from=now/Y+5D+ would exist in the Rails
    # params as +"now/Y 5D"+, with the plus being decoded into a space. We want
    # both the plus sign in the URL, and a plus sign in the decoded value, so
    # we replace that space with a plus sign, yielding +"now/Y+5D"+.

    def from=(from)
      raise unless from.instance_of? String

      @from = from&.tr(" ", "+")
    end

    ##
    # See #from=

    def to=(to)
      raise unless to.instance_of? String

      @to = to&.tr(" ", "+")
    end
  end

  private

  ##
  # A memoized value of now, representing the time the lens is being executed.
  # Since this value gets used several times, even microsecond differences
  # could affect expected behavior. "Now" should be a single moment in time
  # for the entire execution of the lens composition.

  def now
    @now ||= DateTime.now.new_offset(0)
  end

  ##
  # Ensure that when +from+ and +to+ are both defined, the resolved value
  # from +from+ must come before +to+. They cannot be equal.

  def from_must_precede_to
    errors.add(:from, :out_of_order, message: "must precede to") if abs_from && abs_to && abs_from >= abs_to
  end

  ##
  # Takes a string and returns a DateTime. The string is either a date or a
  # date/time in a standard format, or an expression the represents a relative
  # time.
  #
  # When a relative expression is provided, the resolved value is calculated
  # relative to the time when +now+ was first called for this lens
  # composition.
  #
  # Strings for absolute dates and date/times are required to be in a strict
  # format. This is not intended to leniently parse dates and times; only
  # those expected in the URL for a composition, which must be in one of these
  # formats.

  def resolve_to_abs(string, position)
    return unless string

    if string.match Relatime::EXPRESSION_REGEXP
      Relatime.rel2abs(string, position, now)
    elsif string.match?(/^\d{4}-[01]\d-[0-3]\d$/)
      DateTime.parse(string)
    elsif string.match?(/^\d{4}-[01]\d-[0-3]\dT[0-2]\d:[0-5]\d:[0-5]\dZ$/)
      DateTime.parse(string)
    end
  end
end
