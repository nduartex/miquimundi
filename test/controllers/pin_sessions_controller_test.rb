require "test_helper"

class PinSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "pinlogin", pin: "12345678", pin_confirmation: "12345678")
  end

  test "the login form renders" do
    get new_pin_session_path
    assert_response :success
    assert_select "input[name=username]"
    assert_select "input[name=pin]"
  end

  test "logging in with the right username and PIN starts a session" do
    post pin_session_path, params: { username: "pinlogin", pin: "12345678" }
    assert_redirected_to quiniela_path
    get profile_path
    assert_response :success # session is set
  end

  test "username match is case-insensitive" do
    post pin_session_path, params: { username: "PINLOGIN", pin: "12345678" }
    assert_redirected_to quiniela_path
  end

  test "a wrong PIN is rejected with a generic error" do
    post pin_session_path, params: { username: "pinlogin", pin: "00000000" }
    assert_response :unprocessable_entity
    assert_match(/incorrecto/i, response.body)
  end

  test "an unknown username is rejected with the same generic error" do
    post pin_session_path, params: { username: "ghost", pin: "12345678" }
    assert_response :unprocessable_entity
    assert_match(/incorrecto/i, response.body)
  end

  test "a user without a PIN cannot log in this way" do
    User.create!(username: "nopin")
    post pin_session_path, params: { username: "nopin", pin: "12345678" }
    assert_response :unprocessable_entity
  end

  test "too many attempts from one network are throttled" do
    10.times { post pin_session_path, params: { username: "pinlogin", pin: "00000000" } }
    post pin_session_path, params: { username: "pinlogin", pin: "12345678" }
    assert_response :too_many_requests
  end
end
