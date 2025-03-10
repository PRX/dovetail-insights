##
# There are cases where we want to prohibit certain specific behaviors, based
# on various combinations of composition parameters, and perhaps allow them
# only in some limited situations. Those decisions are made in this file.
#
# For example, we broadly do not allow users to group by city or other high
# cardinality dimensions, since that would result in some tens of thousands of
# rows/columns, which is technically difficult to display and likely not useful
# to the user.
#
# But we may allow a user to group by city if they have already added a state
# filter to the composition, since the total number of cites in a single state
# is with reason for displaying to the user.

module CompositionConstraints
  extend ActiveSupport::Concern

  included do
    validate :cities_group_blocked_by_default
  end

  ##
  # Groups with dimension=city_id are blocked by default, but allowed in some
  # situations

  def cities_group_blocked_by_default
    try(:groups)&.each do |group|
      if group&.dimension == :city_id
        if self&.filters&.find { |f| f.dimension == :subdivision_iso_code && f.operator == :include && f.values.size == 1 }
        else
          errors.add(:groups, :cities_restricted, message: "cannot group by city without an active state filter and only 1 state included")
        end
      end
    end
  end
end
