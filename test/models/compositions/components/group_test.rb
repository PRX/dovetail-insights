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

  test "valid meta for dimension" do
    @model.meta = [:podcast_name]
    assert @model.valid?
  end

  test "empty meta" do
    @model.meta = []
    @model.validate
    assert @model.errors.added?(:meta, :missing_metas)
  end

  test "missing meta" do
    @model.meta = [:podcast_id, nil]
    @model.validate
    assert @model.errors.added?(:meta, :missing_metas)
  end

  test "invalid meta for dimension" do
    @model.meta = [:season_number]
    @model.validate
    assert @model.errors.added?(:meta, :invalid)
  end
end
