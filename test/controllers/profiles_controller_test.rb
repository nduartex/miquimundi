require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  def sign_in(user)
    get restore_path(token: user.access_token)
  end

  test "requires login" do
    get profile_path
    assert_redirected_to new_session_path
  end

  test "shows the create-PIN form when the user has no PIN" do
    user = User.create!(username: "nopinprofile")
    sign_in user
    get profile_path
    assert_response :success
    assert_match(/Crear PIN/i, response.body)
    assert_select "input[name=pin]"
  end

  test "shows the change-PIN form when the user already has a PIN" do
    user = User.create!(username: "haspinprofile", pin: "12345678", pin_confirmation: "12345678")
    sign_in user
    get profile_path
    assert_response :success
    assert_match(/Cambiar PIN/i, response.body)
    assert_select "input[name=current_pin]"
  end

  test "the access link is shown on the profile" do
    user = User.create!(username: "linkprofile")
    sign_in user
    get profile_path
    assert_match user.access_token, response.body
  end

  test "the PIN reminder banner shows for users without a PIN and hides once set" do
    user = User.create!(username: "banneruser")
    sign_in user

    get profile_path
    assert_match(/Crea tu PIN/i, response.body)

    user.update!(pin: "12345678", pin_confirmation: "12345678")
    get profile_path
    assert_no_match(/Crea tu PIN/i, response.body)
  end
end
