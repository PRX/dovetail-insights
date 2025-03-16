module SchemaLabelHelper
  ##
  # Returns the best label to represent a schema property or dimension to the
  # user.

  def schema_field_label(field_name, group = nil)
    return "????" unless field_name # TODO

    field_def = DataSchemaUtil.field_definition(field_name)
    field_key_or_name = field_def&.dig("QueryKey") || field_name

    # If there's a explicit localization override, use that. Otherwise, use the
    # query key if it's available, or default to the name.
    base = I18n.exists?("dimensions.#{field_name}") ? t("dimensions.#{field_name}").titleize : field_key_or_name.to_s.titleize

    # For group types with options, include relevant identifying info in the
    # label
    if group&.extract
      "#{group.extract.to_s.titleize} of #{base}"
    elsif group&.truncate
      "#{group.truncate.to_s.titleize} Truncation of #{base}"
    elsif group&.indices
      "#{base} Range"
    else
      base
    end
  end
end
