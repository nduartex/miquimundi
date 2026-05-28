require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires a valid unique email" do
    User.create!(email: "a@b.com")
    dup = User.new(email: "a@b.com")
    assert_not dup.valid?
  end

  test "downcases email before save" do
    user = User.create!(email: "MiXeD@CASE.com")
    assert_equal "mixed@case.com", user.email
  end

  test "rejects malformed email" do
    assert_not User.new(email: "not-an-email").valid?
  end
end
