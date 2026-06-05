require "test_helper"

class PinsControllerTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    get restore_path(token: user.access_token)
  end

  test "requires login" do
    post pin_path, params: { pin: "12345678", pin_confirmation: "12345678" }
    assert_redirected_to new_session_path
  end

  # Create first PIN ------------------------------------------------------

  test "a user without a PIN can create one" do
    user = User.create!(username: "newpin")
    sign_in user
    post pin_path, params: { pin: "12345678", pin_confirmation: "12345678" }
    assert_redirected_to profile_path
    assert user.reload.has_pin?
    assert user.authenticate_pin("12345678")
  end

  test "creating a PIN rejects a bad format" do
    user = User.create!(username: "badnewpin")
    sign_in user
    post pin_path, params: { pin: "abc", pin_confirmation: "abc" }
    assert_response :unprocessable_entity
    assert_not user.reload.has_pin?
  end

  test "creating a PIN rejects a blank PIN (does not falsely succeed)" do
    user = User.create!(username: "blanknewpin")
    sign_in user
    post pin_path, params: { pin: "", pin_confirmation: "" }
    assert_response :unprocessable_entity
    assert_not user.reload.has_pin?
  end

  test "creating a PIN rejects an array-typed pin param (no false success)" do
    user = User.create!(username: "arraynewpin")
    sign_in user
    post pin_path, params: { pin: [ "12345678" ], pin_confirmation: [ "12345678" ] }
    assert_response :unprocessable_entity
    assert_not user.reload.has_pin?
  end

  test "creating a PIN rejects a mismatched confirmation" do
    user = User.create!(username: "mismatchpin")
    sign_in user
    post pin_path, params: { pin: "12345678", pin_confirmation: "00000000" }
    assert_response :unprocessable_entity
    assert_not user.reload.has_pin?
  end

  test "a failed create still renders the create form, not the change form" do
    user = User.create!(username: "rerenderpin")
    sign_in user
    post pin_path, params: { pin: "abc", pin_confirmation: "abc" }
    assert_response :unprocessable_entity
    assert_match(/Crear PIN/i, response.body)
    assert_select "input[name=current_pin]", false, "must not show the change-PIN form"
  end

  test "a user who already has a PIN is redirected away from create" do
    user = User.create!(username: "haspin", pin: "12345678", pin_confirmation: "12345678")
    sign_in user
    post pin_path, params: { pin: "99999999", pin_confirmation: "99999999" }
    assert_redirected_to profile_path
    assert user.reload.authenticate_pin("12345678"), "the PIN must not have changed"
  end

  # Change PIN ------------------------------------------------------------

  test "changing the PIN with the correct current PIN works" do
    user = User.create!(username: "changepin", pin: "12345678", pin_confirmation: "12345678")
    sign_in user
    patch pin_path, params: { current_pin: "12345678", pin: "87654321", pin_confirmation: "87654321" }
    assert_redirected_to profile_path
    assert user.reload.authenticate_pin("87654321")
  end

  test "changing the PIN rejects a blank new PIN (keeps the old one)" do
    user = User.create!(username: "blankchange", pin: "12345678", pin_confirmation: "12345678")
    sign_in user
    patch pin_path, params: { current_pin: "12345678", pin: "", pin_confirmation: "" }
    assert_response :unprocessable_entity
    assert user.reload.authenticate_pin("12345678"), "the PIN must not have changed"
  end

  test "changing the PIN with the wrong current PIN is rejected" do
    user = User.create!(username: "wrongcurrent", pin: "12345678", pin_confirmation: "12345678")
    sign_in user
    patch pin_path, params: { current_pin: "00000000", pin: "87654321", pin_confirmation: "87654321" }
    assert_response :unprocessable_entity
    assert user.reload.authenticate_pin("12345678"), "the PIN must not have changed"
  end
end
