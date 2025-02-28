# TODO This is not meant to be a permanent solution
class Lists
  def self.all_podcasts
    Rails.cache.fetch("podcast", expires_in: 12.hours) do
      data = BigQueryClient.instance.query("SELECT id, title, account_id FROM production.podcasts ORDER BY title ASC")

      rows = []
      data.all do |row|
        rows << row
      end

      rows
    end
  end

  def self.list_for(dimension_key, accounts = [])
    if dimension_key == "country"
      Rails.cache.fetch("country", expires_in: 12.hours) do
        data = BigQueryClient.instance.query("SELECT country_iso_code, country_name FROM production.geonames WHERE country_name <> '' AND subdivision_1_iso_code IS NULL AND subdivision_2_iso_code IS NULL AND city_name IS NULL ORDER BY country_name ASC")

        rows = []
        data.all do |row|
          rows << row
        end

        rows
      end
    elsif dimension_key == "ua"
      Rails.cache.fetch("ua", expires_in: 12.hours) do
        # Fetch all agent names. This includes UAs, OSs, and device types
        data = BigQueryClient.instance.query("SELECT agentname_id, tag FROM production.agentnames ORDER BY tag ASC")

        rows = []
        data.all do |row|
          rows << row
        end

        os_ids = Lists.list_for("os").map { |h| h[:key] }
        device_ids = Lists.list_for("device").map { |h| h[:key] }
        exclude_ids = os_ids + device_ids

        # Take out the OSs and device types to end up with use UAs
        rows.filter { |r| !exclude_ids.include?(r[r.keys[0]]) }
      end
    elsif dimension_key == "podcast"
      all_podcasts.filter { |p| accounts.include?(p[p.keys[2]].to_s) }
    elsif dimension_key == "os"
      [
        {key: 44, value: "Amazon OS"},
        {key: 42, value: "Android"},
        {key: 46, value: "BlackberryOS"},
        {key: 48, value: "ChromeOS"},
        {key: 43, value: "iOS"},
        {key: 49, value: "Linux"},
        {key: 45, value: "macOS"},
        {key: 50, value: "webOS"},
        {key: 41, value: "Windows"},
        {key: 47, value: "Windows Phone"}
      ]
    elsif dimension_key == "device"
      [
        {key: 35, value: "Desktop App"},
        {key: 39, value: "Desktop Browser"},
        {key: 36, value: "Mobile App"},
        {key: 40, value: "Mobile Browser"},
        {key: 37, value: "Smart Home"},
        {key: 38, value: "Smart TV"}
      ]
    elsif dimension_key == "continent"
      [
        {key: "AF", value: "Africa"},
        {key: "AN", value: "Antarctica"},
        {key: "AS", value: "Asia"},
        {key: "EU", value: "Europe"},
        {key: "NA", value: "North America"},
        {key: "OC", value: "Oceania"},
        {key: "SA", value: "South America"}
      ]
    elsif dimension_key == "metro"
      Rails.cache.fetch("metro", expires_in: 12.hours) do
        data = BigQueryClient.instance.query("SELECT code, label FROM production.metronames ORDER BY label ASC")

        rows = []
        data.all do |row|
          rows << row
        end

        rows
      end
    elsif dimension_key == "tz"
      Rails.cache.fetch("tz", expires_in: 12.hours) do
        data = BigQueryClient.instance.query("SELECT time_zone AS t1, time_zone AS t2 FROM production.geonames WHERE time_zone <> '' GROUP BY time_zone ORDER BY time_zone ASC")

        rows = []
        data.all do |row|
          rows << row
        end

        rows.filter { |r| r[r.keys[0]].present? }
      end
    elsif dimension_key == "subdivX"
      Rails.cache.fetch("subdiv6", expires_in: 12.hours) do
        data = BigQueryClient.instance.query("SELECT CONCAT(country_iso_code, '-', subdivision_1_iso_code) AS t1, CONCAT(subdivision_1_name, ', ', country_name) AS t2 FROM production.geonames WHERE subdivision_1_iso_code <> '' AND subdivision_2_iso_code IS NULL AND city_name IS NULL GROUP BY subdivision_1_iso_code, subdivision_1_name, country_name, country_iso_code ORDER BY subdivision_1_name ASC, country_name ASC")

        rows = []
        data.all do |row|
          rows << row
        end

        rows.filter { |r| r[r.keys[0]].present? }
      end
    elsif dimension_key == "cityX"
      Rails.cache.fetch("city3", expires_in: 12.hours) do
        data = BigQueryClient.instance.query("SELECT geoname_id AS t1, CONCAT(city_name, ', ', subdivision_1_name, ', ', country_name) AS t2 FROM production.geonames WHERE city_name <> '' GROUP BY geoname_id, country_iso_code, country_name, subdivision_1_iso_code, subdivision_1_name, subdivision_2_iso_code, city_name ORDER BY city_name ASC, country_name ASC")

        rows = []
        data.all do |row|
          rows << row
        end

        rows.filter { |r| r[r.keys[0]].present? }
      end
    elsif dimension_key == "advertiserX"
      Rails.cache.fetch("advertiser", expires_in: 12.hours) do
        data = BigQueryClient.instance.query("SELECT id, name FROM production.advertisers ORDER BY name ASC")

        rows = []
        data.all do |row|
          rows << row
        end

        rows
      end
    elsif dimension_key == "campaignX"
      Rails.cache.fetch("campaign", expires_in: 12.hours) do
        data = BigQueryClient.instance.query("SELECT id, name FROM production.campaigns ORDER BY name ASC")

        rows = []
        data.all do |row|
          rows << row
        end

        rows
      end
    elsif dimension_key == "season"
      20.times.map { |i| {key: (i + 1).to_s, value: (i + 1).to_s} }
    elsif dimension_key == "episodeNumber"
      50.times.map { |i| {key: (i + 1).to_s, value: (i + 1).to_s} }
    end
  end
end
