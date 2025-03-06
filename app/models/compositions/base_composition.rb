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
    attr_reader :big_query_total_bytes_billed

    # TODO Needing to set this is pretty hacky
    attr_accessor :unauthorized_podcast_ids

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
      raise if filters.any? { |f| !f.instance_of? Components::Filter }
      @filters = filters
    end

    def as_json(options = {})
      obj = {}

      obj[:lens] = lens if lens
      obj[:from] = from if from
      obj[:to] = to if to

      obj[:filters] = filters.map { |f| f.as_json(options) } if filters

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

    def require_explicit_podcast_selection
      podcast_filter = filters&.find { |f| f.dimension == :podcast_id }

      errors.add(:filters, "must include a podcast filter") if !podcast_filter

      # TODO Adding errors outside of #validate doesn't play nicely with .valid?
      podcast_filter.errors.add(:operator, "can only be 'include'") if podcast_filter && podcast_filter.operator != :include
    end

    def only_authorized_podcasts
      if unauthorized_podcast_ids
        errors.add(:filters, :unauthorized, message: "must not include unauthorized podcasts")

        # TODO Adding errors outside of #validate doesn't play nicely with .valid?
        podcast_filter = filters&.find { |f| f.dimension == :podcast_id }
        podcast_filter.errors.add(:values, "must not include unauthorized podcasts")
      end
    end
  end
end
