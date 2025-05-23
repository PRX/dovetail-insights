require "ostruct"

DataSchema = OpenStruct.new

# TODO Validate that no entities have the same name

DataSchema.dimensions = YAML.load_file(Rails.root.join("db/data_schema/dimensions.yml").to_s)["Dimensions"]
DataSchema.properties = YAML.load_file(Rails.root.join("db/data_schema/properties.yml").to_s)["Properties"]
DataSchema.metrics = YAML.load_file(Rails.root.join("db/data_schema/metrics.yml").to_s)["Metrics"]
DataSchema.tables = YAML.load(ERB.new(File.read(Rails.root.join("db/data_schema/tables.yml").to_s)).result)["Tables"]

class DataSchemaUtil
  ##
  # Return the definition for a field in the data schema (i.e., a dimension or
  # property). This assumes that names of dimensions and properties are all
  # globally unique.

  def self.field_definition(field_name)
    DataSchema.dimensions[field_name.to_s] || DataSchema.properties[field_name.to_s]
  end

  def self.dimension_name_for_query_key(query_key)
    DataSchema.dimensions.find { |k, v| v["QueryKey"] == query_key }&.dig(0)
  end

  def self.property_name_for_query_key(query_key)
    DataSchema.properties.find { |k, v| v["QueryKey"] == query_key }&.dig(0)
  end

  def self.field_name_for_query_key(query_key)
    dimension_name_for_query_key(query_key) || property_name_for_query_key(query_key)
  end
end
