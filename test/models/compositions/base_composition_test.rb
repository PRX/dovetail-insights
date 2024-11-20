require "test_helper"

class BaseCompositionTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Compositions::BaseComposition.new
    @model.from = "now/m"
    @model.to = "now/m"
    @model.filters = []
  end

  test "base never valid" do
    assert_not @model.valid?
    assert @model.errors.include?(:lens)
    assert_not @model.errors.include?(:from)
    assert_not @model.errors.include?(:to)
  end

  test "no range" do
    model = Compositions::BaseComposition.new

    model.valid?
    assert model.errors.added?(:from, :blank)
    assert model.errors.added?(:to, :blank)
  end

  test "from params" do
    model = Compositions::BaseComposition.from_params(ActionController::Parameters.new({
      from: "now/Y",
      to: "now/M"
    }))

    assert_equal "now/Y", model.from
    assert_equal "now/M", model.to
    assert_equal 0, model.filters.size
  end
end
