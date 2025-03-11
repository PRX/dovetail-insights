require "ostruct"
require "csv"

class DataExplorerController < ApplicationController
  rate_limit to: 4, within: 1.minute unless Rails.env.development?

  before_action :load_composition

  def index
    if @composition.valid? && @composition.results && @composition.bigquery_total_bytes_billed
      CompositionResultMetadataLog.create!(user_id: current_user.user_id, total_bytes_processed: @composition.bigquery_total_bytes_billed, params: params.to_s)
    end

    @bytes = CompositionResultMetadataLog.where(current_user.user_id).where("created_at >= ?", 48.hours.ago).pluck(:total_bytes_processed).reduce(0, :+)
  end

  def bookmarks
    @bytes = CompositionResultMetadataLog.where(current_user.user_id).where("created_at >= ?", 48.hours.ago).pluck(:total_bytes_processed).reduce(0, :+)
  end

  def export
    if @composition.valid?
      send_data(
        @composition.results.as_csv,
        filename: "export.csv",
        type: :csv
      )
    end
  end

  protected

  def load_composition
    @composition = case params[:lens]
    when Compositions::DimensionalComposition.query_value
      Compositions::DimensionalComposition.from_params(params)
    when Compositions::TimeSeriesComposition.query_value
      Compositions::TimeSeriesComposition.from_params(params)
    when Compositions::CumeComposition.query_value
      Compositions::CumeComposition.from_params(params)
    else
      Compositions::BaseComposition.from_params(params)
    end

    @composition.user = current_user

    @composition
  end
end
