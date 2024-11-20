require "ostruct"

class DataExplorerController < ApplicationController
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
end
