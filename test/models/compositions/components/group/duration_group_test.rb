require "test_helper"

class DurationGroupTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Compositions::Components::Group.new(:current_episode_age_in_seconds)
    @model.indices = [1, 2, 3]
  end

  test "valid construction" do
    assert @model.valid?
  end

  test "invalid options" do
    @model.truncate = :year
    @model.extract = :year
    @model.validate
    assert @model.errors.added?(:truncate, :option_mismatch)
    assert @model.errors.added?(:extract, :option_mismatch)
  end

  test "invalid indices" do
    @model.indices = ["bogus"]
    @model.validate
    assert @model.errors.added?(:indices, :invalid)

    @model.indices = [123.456]
    @model.validate
    assert @model.errors.added?(:indices, :invalid)

    @model.indices = ["123.456D"]
    @model.validate
    assert @model.errors.added?(:indices, :invalid)
  end

  test "duplicate indices" do
    @model.indices = [42, 42]
    @model.validate
    assert @model.errors.added?(:indices, :duplicates)
  end

  test "out of order indices" do
    @model.indices = [999, 42]
    @model.validate
    assert @model.errors.added?(:indices, :out_of_order)
  end

  test "blank indices" do
    @model.indices = [1, nil, 2]
    @model.validate
    assert @model.errors.added?(:indices, :missing_indices)
  end

  test "empty indices" do
    @model.indices = []
    @model.validate
    assert @model.errors.added?(:indices, :missing_indices)
  end
end
