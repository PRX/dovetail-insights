module SchemaLabelHelper
  ##
  # Returns the best label to represent a schema property or dimension to the
  # user.

  def prop_or_dim_label(prop_or_dim_name)
    field_def = DataSchemaUtil.field_definition(prop_or_dim_name)
    prop_or_dim_key = field_def["QueryKey"] || prop_or_dim_name

    # If there's a explicit localization override, use that. Otherwise, use the
    # query key if it's available, or default to the name.
    I18n.exists?("dimensions.#{prop_or_dim_name}") ? t("dimensions.#{prop_or_dim_name}").titleize : prop_or_dim_key.to_s.titleize
  end
end
