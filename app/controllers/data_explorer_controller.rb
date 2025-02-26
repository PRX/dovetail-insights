require "ostruct"
require "csv"

class DataExplorerController < ApplicationController
  rate_limit to: 4, within: 1.minute unless Rails.env.development?

  before_action :load_composition
  before_action :check_podcast_authorization

  def index
    if @composition.valid? && @composition.results && @composition.big_query_total_bytes_billed
      CompositionResultMetadataLog.create!(user_id: current_user.user_id, total_bytes_processed: @composition.big_query_total_bytes_billed, params: params.to_s)
    end

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
    else
      Compositions::BaseComposition.from_params(params)
    end
  end

  def check_podcast_authorization
    # TODO It would be better if this could be handled as a composition
    # validation, but since it relies on the user JWT, it's not obvious how to
    # make that happen. Passing the JWT in to the Composition constructor
    # doesn't seem right. Just adding an error to the composition or the filter
    # doesn't make .valid? fail.
    podcast_filter = @composition&.filters&.find { |f| f.dimension == :podcast_id }

    return unless podcast_filter

    all_valid = podcast_filter&.values&.all? do |podcast_id|
      all_podcasts = Lists.all_podcasts
      podcast = all_podcasts.find { |podcast| podcast[:id] == podcast_id.to_i }

      podcast && @current_user_podcast_accounts.include?(podcast[:account_id].to_s)
    end

    unless all_valid
      render plain: "podcast ID not authorized"
    end
  end
end
