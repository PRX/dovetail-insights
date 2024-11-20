require "test_helper"

class FilterTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Compositions::Components::Filter.new(:podcast_id)
    @model.operator = :include
  end

  test "is valid" do
    assert @model.valid?
  end

  test "invalid dimension" do
    model = Compositions::Components::Filter.new(:foo)
    model.operator = :include

    assert_not model.valid?
  end
end
