require "google/cloud/bigquery"
require "logger"

google_logger = Logger.new $stderr
google_logger.level = Logger::WARN

Google::Apis.logger = google_logger

BIG_QUERY_PRICE_PER_TIB = 6.25

module BigQueryClient
  def self.instance
    @instance ||= Google::Cloud::Bigquery.new
  end
end
