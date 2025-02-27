require "test_helper"

class TokenGroupTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Compositions::Components::Group.new(:podcast_id)
  end

  test "valid construction" do
    assert @model.valid?
  end

  test "invalid options" do
    @model.truncate = :year
    @model.extract = :year
    @model.indices = [1, 2, 3]
    @model.validate
    assert @model.errors.added?(:truncate, :option_mismatch)
    assert @model.errors.added?(:extract, :option_mismatch)
    assert @model.errors.added?(:indices, :option_mismatch)
  end
end
