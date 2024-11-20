require "ostruct"

DataSchema = OpenStruct.new

DataSchema.dimensions = YAML.load_file(File.join(Rails.root, "db", "data_schema", "dimensions.yml"))["Dimensions"]
DataSchema.properties = YAML.load_file(File.join(Rails.root, "db", "data_schema", "properties.yml"))["Properties"]
DataSchema.metrics = YAML.load_file(File.join(Rails.root, "db", "data_schema", "metrics.yml"))["Metrics"]
DataSchema.tables = YAML.load_file(File.join(Rails.root, "db", "data_schema", "tables.yml"))["Tables"]
