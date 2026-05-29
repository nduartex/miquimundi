require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "logging in with a new email creates a user and session" do
    assert_difference "User.count", 1 do
      post session_path, params: { email: "new@user.com" }
    end
    assert_redirected_to quiniela_path
  end

  test "logging in with existing email reuses the user" do
    User.create!(email: "old@user.com")
    assert_no_difference "User.count" do
      post session_path, params: { email: "OLD@user.com" }
    end
  end

  test "rejects invalid email" do
    post session_path, params: { email: "nope" }
    assert_response :unprocessable_entity
  end
end
