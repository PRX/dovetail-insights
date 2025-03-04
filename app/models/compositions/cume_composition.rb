module Compositions
  ##
  # TODO tktk

  class CumeComposition < BaseComposition
    def self.query_value
      "cume"
    end

    def self.from_params(params)
      composition = super

      composition.groups = Components::Group.all_from_params(params)
      composition.metrics = Components::Metric.all_from_params(params)

      composition
    end

    attr_accessor :metrics, :groups

    # TODO validate to prevent comparisons
    # TODO validate to prevent group 2

    def results
    end
  end
end
