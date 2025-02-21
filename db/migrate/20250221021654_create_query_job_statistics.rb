class CreateQueryJobStatistics < ActiveRecord::Migration[8.0]
  def change
    create_table :query_job_statistics do |t|
      t.integer :user_id, null: false
      t.integer :total_bytes_processed, null: false
      t.string :params, null: false

      t.timestamps
    end
  end
end
