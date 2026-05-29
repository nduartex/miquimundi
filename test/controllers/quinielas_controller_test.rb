require "test_helper"

class QuinielasControllerTest < ActionDispatch::IntegrationTest
  def setup
    SeedLoader.call
    @user = User.create!(email: "p@x.com")
    post session_path, params: { email: @user.email }
  end

  test "show renders the wizard with groups, knockouts and locked awards" do
    get quiniela_path
    assert_response :success
    assert_select "h1", text: "Mi Quiniela"
    assert_match "Grupo A", response.body
    assert_match "Octavos", response.body          # i18n phase label rendered
    assert_match "desbloquear los premios", response.body  # awards locked until final predicted
  end

  test "show requires login" do
    delete session_path
    get quiniela_path
    assert_redirected_to new_session_path
  end
end
