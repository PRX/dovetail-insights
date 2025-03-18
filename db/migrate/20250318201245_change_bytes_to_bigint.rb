class ChangeBytesToBigint < ActiveRecord::Migration[8.0]
  def up
    add_column :composition_result_metadata_logs, :total_bytes_processed_tmp, :bigint
    execute "UPDATE composition_result_metadata_logs SET total_bytes_processed_tmp = total_bytes_processed"
    remove_column :composition_result_metadata_logs, :total_bytes_processed
    rename_column :composition_result_metadata_logs, :total_bytes_processed_tmp, :total_bytes_processed
  end

  def down
    add_column :composition_result_metadata_logs, :total_bytes_processed_tmp, :integer
    execute "UPDATE composition_result_metadata_logs SET total_bytes_processed_tmp = total_bytes_processed"
    remove_column :composition_result_metadata_logs, :total_bytes_processed
    rename_column :composition_result_metadata_logs, :total_bytes_processed_tmp, :total_bytes_processed
  end
end
