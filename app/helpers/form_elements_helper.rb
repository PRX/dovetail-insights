module FormElementsHelper
  def select_eq(bool_or_expected, actual = nil)
    if actual
      html_attributes(selected: :selected) if expected == actual
    elsif bool_or_expected
      html_attributes(selected: :selected)
    end
  end
end
