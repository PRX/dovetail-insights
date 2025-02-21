class RenameQueryJobStatisticsToCompositionResultMetadataLogs < ActiveRecord::Migration[8.0]
  def change
    rename_table :query_job_statistics, :composition_result_metadata_logs
  end
end
