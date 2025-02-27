require "test_helper"

class TimestampGroupTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Compositions::Components::Group.new(:episode_publish_timestamp)
  end

  test "valid construction" do
    @model.extract = :year
    assert @model.valid?
  end

  test "no options" do
    @model.validate
    assert @model.errors.added?(:dimension, :invalid_option)
  end

  test "multiple options invalid" do
    @model.extract = :year
    @model.truncate = :year
    @model.indices = [1, 2, 3]
    @model.validate
    assert @model.errors.added?(:extract, :option_conflict)
    assert @model.errors.added?(:truncate, :option_conflict)
    assert @model.errors.added?(:indices, :option_conflict)
  end
end
