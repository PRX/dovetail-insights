require "test_helper"

class TimestampExtractGroupTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Compositions::Components::Group.new(:episode_publish_timestamp)
    @model.extract = :year
  end

  test "valid construction" do
    assert @model.valid?
  end

  test "invalid option" do
    @model.extract = :bogus
    @model.validate
    assert @model.errors.include?(:extract)
  end
end
