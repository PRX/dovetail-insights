require "test_helper"

class GroupTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Compositions::Components::Group.new(:podcast_id)
  end

  test "invalid dimension" do
    group = Compositions::Components::Group.new(:bogus)
    group.validate
    assert group.errors.added?(:dimension, :invalid)
  end
end
