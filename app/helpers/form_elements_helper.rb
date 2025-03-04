module FormElementsHelper
  ##
  # Returns `selected="selected"` when the condition is true. The condition can
  # either be a single boolean, or two values which will be compared

  def select_eq(bool_or_expected, actual = nil)
    if actual
      html_attributes(selected: :selected) if expected == actual
    elsif bool_or_expected
      html_attributes(selected: :selected)
    end
  end
end
