module SchemaLabelHelper
  ##
  # Returns the best label to represent a schema property or dimension to the
  # user.

  def prop_or_dim_label(prop_or_dim_name)
    prop_or_dim_def = DataSchema.dimensions[prop_or_dim_name.to_s] || DataSchema.properties[prop_or_dim_name.to_s]
    prop_or_dim_key = prop_or_dim_def["QueryKey"] || prop_or_dim_name

    # If there's a explicit localization override, use that. Otherwise, use the
    # query key if it's available, or default to the name.
    I18n.exists?("dimensions.#{prop_or_dim_name}") ? t("dimensions.#{prop_or_dim_name}").titleize : prop_or_dim_key.titleize
  end
end
