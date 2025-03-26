module Compositions
  ##
  # An abstract class that provides common functionality for Data Explorer
  # compositions.
  #
  # All lenses support: range (from and to) and filters.

  class BaseComposition
    include ActiveModel::Model

    def self.query_value
      nil
    end

    def self.from_params(params)
      composition = new

      composition.from = params[:from] if params[:from]
      composition.to = params[:to] if params[:to]
      composition.filters = Components::Filter.all_from_params(params)

      composition
    end

    include Ranging
    include Warnings
    include CompositionConstraints

    attr_reader :filters
    attr_reader :bigquery_total_bytes_billed

    attr_accessor :user

    # All lenses support and require a time range define by +from+ and +to+.
    # These values are mostly handled by +Ranging+.
    validates :from, :to, presence: true

    validate :lens_must_not_be_base_class, :all_filters_are_valid
    validate :require_explicit_podcast_selection
    validate :only_authorized_podcasts

    def query_value
      self.class.query_value
    end

    # This is for the `lens` reference in form_with
    def lens
      query_value
    end

    def filters=(filters)
      raise "Invalid filter object" if filters.any? { |f| !f.instance_of? Components::Filter }
      @filters = filters
    end

    def enabled_filters
      filters.filter { |f| !f.disabled }
    end

    # Calling +valid?+ seems to run validations more than I would expect, since
    # they shoud be memoized. This is a workaround to strictly memoize result.
    def memo_valid?
      @memo_valid ||= valid?
    end

    def as_json(options = {})
      obj = {}

      obj[:lens] = lens if lens
      obj[:from] = from if from
      obj[:to] = to if to

      obj[:filters] = filters.map { |f| f.as_json(options) } if filters.present?

      obj
    end

    def to_json(*options)
      as_json.to_json(*options)
    end

    private

    ##
    # Validation that always fails if it's this base class that is being
    # validated. This ensure that only subclasses are actually used.

    def lens_must_not_be_base_class
      if instance_of? BaseComposition
        errors.add(:lens, :missing_lens, message: "type must be selected")
      end
    end

    def all_filters_are_valid
      if (filters || []).any? { |f| f.invalid? }
        errors.add(:filters, :invalid_filters, message: "must all be valid")
      end
    end

    ##
    # We want to ensure that all queries include data for specific podcasts.
    # When combined with the +only_authorized_podcasts+ validation, this
    # ensures that data can't leak out for podcasts that a user is not
    # authorized to view, like would be possible if a user set an
    # EXCLUDE podcast=[3,4,5] filter, even if they were authorized for podcasts
    # 3, 4 and 5, as that query would leak data for podcasts 1, 2, 6, 7, etc.

    def require_explicit_podcast_selection
      podcast_filter = filters&.find { |f| f.dimension == :podcast_id }

      errors.add(:filters, "must include a podcast filter") if !podcast_filter

      # TODO Adding errors outside of #validate doesn't play nicely with .valid?
      if podcast_filter && podcast_filter.operator != :include
        errors.add(:filters, "must use include for podcast filter")
        podcast_filter.errors.add(:operator, "can only be 'include'")
      end
    end

    def only_authorized_podcasts
      podcast_filter = filters&.find { |f| f.dimension == :podcast_id }

      return unless podcast_filter

      user_podcast_accounts ||= (user.resources(:feeder, :read_private) + user.resources(:augury, :campaign))
      all_podcasts = Lists.all_podcasts

      invalid_podcasts = podcast_filter&.values&.select do |podcast_id|
        podcast = all_podcasts.find { |podcast| podcast[:id] == podcast_id.to_i }
        authed = user_podcast_accounts.include?(podcast[:account_id].to_s)

        !podcast || !authed
      end

      if !user || (invalid_podcasts && invalid_podcasts.size > 0)
        errors.add(:filters, :unauthorized, message: "must not include unauthorized podcasts (#{invalid_podcasts.join(", ")})")

        # TODO Adding errors outside of #validate doesn't play nicely with .valid?
        podcast_filter.errors.add(:values, "must not include unauthorized podcasts")
      end
    end
  end
end
