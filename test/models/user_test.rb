require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires a unique username (case-insensitive)" do
    User.create!(username: "Martin")
    dup = User.new(username: "martin")
    assert_not dup.valid?
  end

  test "rejects too-short or invalid usernames" do
    assert_not User.new(username: "ab").valid?
    assert_not User.new(username: "has spaces").valid?
    assert User.new(username: "martin_10").valid?
  end

  test "generates a unique access token on create" do
    user = User.create!(username: "tokenuser")
    assert user.access_token.present?
    assert_not_equal user.access_token, User.create!(username: "tokenuser2").access_token
  end

  test "display_name falls back to username" do
    assert_equal "neo", User.new(username: "neo").display_name
    assert_equal "Neo R", User.new(username: "neo", name: "Neo R").display_name
  end
end
