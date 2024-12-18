require "ostruct"
require "csv"

class DataExplorerController < ApplicationController
  rate_limit to: 4, within: 1.minute

  def index
    @composition = case params[:lens]
    when Compositions::DimensionalComposition.query_value
      Compositions::DimensionalComposition.from_params(params)
    when Compositions::TimeSeriesComposition.query_value
      Compositions::TimeSeriesComposition.from_params(params)
    else
      Compositions::BaseComposition.from_params(params)
    end
  end

  def export
    @composition = case params[:lens]
    when Compositions::DimensionalComposition.query_value
      Compositions::DimensionalComposition.from_params(params)
    when Compositions::TimeSeriesComposition.query_value
      Compositions::TimeSeriesComposition.from_params(params)
    else
      Compositions::BaseComposition.from_params(params)
    end

    if @composition.valid?
      send_data(
        @composition.results.as_csv,
        filename: "export.csv",
        type: :csv
      )
    end
  end
end
