require "test_helper"

class GroupTest < ActiveSupport::TestCase
  test "has many teams ordered" do
    assert_respond_to Group.new, :teams
  end

  test "requires a name" do
    group = Group.new
    assert_not group.valid?
    assert_includes group.errors[:name], "no puede estar en blanco"
  end
end
