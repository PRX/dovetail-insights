class TypeaheadController < ApplicationController
  def filter_with_limit(array, n)
    result = []
    array.each do |item|
      result << item if yield(item)
      break if result.size >= n
    end
    result
  end

  def cities
    all_cities = Rails.cache.fetch("typeahead_cities", expires_in: 12.hours) do
      data = BigqueryClient.instance.query("SELECT geoname_id AS t1, CONCAT(city_name, ', ', subdivision_1_name, ', ', country_name) AS t2, city_name FROM #{ENV.fetch("BIGQUERY_DATASET", "staging")}.geonames WHERE city_name <> '' GROUP BY geoname_id, country_iso_code, country_name, subdivision_1_iso_code, subdivision_1_name, subdivision_2_iso_code, city_name ORDER BY city_name ASC, country_name ASC")

      rows = []
      data.all { |row| rows << row }

      rows.filter { |r| r[r.keys[0]].present? }
    end

    if params[:q].present?
      cities = filter_with_limit(all_cities, 50) { |c| c[:city_name].downcase.include?(params[:q].downcase) }
    else
      cities = []
    end

    render json: cities
  end
end
