module SchemaLabelHelper
  ##
  # Returns the best label to represent a schema property or dimension to the
  # user.

  def prop_or_dim_label(field_name)
    return "????" unless field_name # TODO

    field_def = DataSchemaUtil.field_definition(field_name)
    field_key_or_name = field_def&.dig("QueryKey") || field_name

    # If there's a explicit localization override, use that. Otherwise, use the
    # query key if it's available, or default to the name.
    p field_name
    p t("dimensions.#{field_name}")
    I18n.exists?("dimensions.#{field_name}") ? t("dimensions.#{field_name}").titleize : field_key_or_name.to_s.titleize
  end
end
