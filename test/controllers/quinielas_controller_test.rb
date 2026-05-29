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
    assert_match "desbloquear el goleador", response.body  # awards locked until final predicted
  end

  test "show includes the onboarding tour and goal steppers, no pending line" do
    get quiniela_path
    assert_response :success
    assert_match 'data-tour-name-value="mi-quiniela"', response.body  # onboarding tour wired
    assert_select "#stat-puntos"                                       # tour anchor exists
    assert_match "stepper#inc", response.body                          # goal stepper controls
    assert_no_match(/partidos pendientes/, response.body)              # pending line removed
  end

  test "show requires login" do
    delete session_path
    get quiniela_path
    assert_redirected_to new_session_path
  end
end
