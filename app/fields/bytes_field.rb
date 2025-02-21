require "administrate/field/base"

class BytesField < Administrate::Field::Base
  def to_s
    ActionController::Base.helpers.number_to_human_size(data)
  end
end
