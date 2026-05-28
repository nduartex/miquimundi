require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "is invalid without a name" do
    team = Team.new(code: "BRA")
    assert_not team.valid?
    assert_includes team.errors[:name], "can't be blank"
  end

  test "belongs to a group and has players" do
    assert_respond_to Team.new, :group
    assert_respond_to Team.new, :players
  end
end
