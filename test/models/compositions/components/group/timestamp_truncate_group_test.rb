require "test_helper"

class TimestampTruncateGroupTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Compositions::Components::Group.new(:episode_publish_timestamp)
    @model.truncate = :year
  end

  test "valid construction" do
    assert @model.valid?
  end

  test "invalid option" do
    @model.truncate = :bogus
    @model.validate
    assert @model.errors.include?(:truncate)
  end
end
