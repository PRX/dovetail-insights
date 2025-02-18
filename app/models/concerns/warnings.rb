##
# Replicates the standard ActiveModel Errors functionality, but under the name
# +warnings+. Meaning you can do things like +warnings.add(:foo)+,
# +warnings.include?(:foo)+, etc.
#
# Also provides a +safe?+ method which returns +true+ when there are no
# warnings. This is similar to +valid?+ provided by +ActiveModel::Validations+,
# but does not behave exactly the same.
#
# Be aware that this does not change the default behavior of validations, which
# will continue to operate only on +errors+. You can add warnings through
# +validate+ if you want, though, just realize that you will introduce some
# discontinuity between +validate+ and +valid?+.

module Warnings
  extend ActiveSupport::Concern

  included do
    def warnings
      @warnings ||= ActiveModel::Errors.new(self)
    end

    def safe?
      warnings.empty?
    end
  end
end
