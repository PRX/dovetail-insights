require "test_helper"

class TimestampRangeGroupTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Compositions::Components::Group.new(:episode_publish_timestamp)
    @model.indices = ["2020-01-01", "2021-01-01T12:34:56Z", "now"]
  end

  test "valid construction" do
    assert @model.valid?
    assert @model.safe?
  end

  test "invalid indices" do
    @model.indices = [2020]
    @model.validate
    assert @model.errors.added?(:indices, :invalid)

    @model.indices = ["2020"]
    @model.validate
    assert @model.errors.added?(:indices, :invalid)
  end

  test "duplicate indices" do
    @model.indices = ["now", "now"]
    @model.validate
    assert @model.errors.added?(:indices, :duplicates)
  end

  test "out of order indices" do
    @model.indices = ["now", "now-7/D"]
    @model.validate
    assert @model.errors.added?(:indices, :out_of_order)
  end
end
