require "test_helper"

class QuinielasControllerTest < ActionDispatch::IntegrationTest
  def setup
    SeedLoader.call
    @user = User.create!(email: "p@x.com")
    post session_path, params: { email: @user.email }
  end

  test "show renders the 4-step wizard with groups, thirds and locked knockouts" do
    get quiniela_path
    assert_response :success
    assert_select "h1", text: "Mi Quiniela"
    assert_match "Grupo A", response.body
    assert_match "8 mejores terceros", response.body         # thirds step
    assert_match "Eliminatorias bloqueadas", response.body   # knockout locked until groups end
    assert_match "Premios individuales", response.body       # awards available from the start
  end

  test "show includes the onboarding tour and the thirds picker, no pending line" do
    get quiniela_path
    assert_response :success
    assert_match 'data-tour-name-value="mi-quiniela"', response.body
    assert_select "#stat-puntos"
    assert_match 'data-controller="thirds"', response.body
    assert_no_match(/partidos pendientes/, response.body)
  end

  test "group stage uses sortable team ordering with real flag images" do
    get quiniela_path
    assert_response :success
    assert_match 'data-controller="group-order"', response.body
    assert_match "https://flagcdn.com/mx.svg", response.body
    assert_select "li[draggable=true]"
    assert_select "input[type=hidden][name=?]", "group_predictions[#{Group.find_by(name: 'A').id}][fourth_team_id]"
  end

  test "thirds picker offers one checkbox per group" do
    get quiniela_path
    assert_response :success
    assert_select "input[type=checkbox][name=?]", "best_third_groups[]", count: 12
  end

  test "show requires login" do
    delete session_path
    get quiniela_path
    assert_redirected_to new_session_path
  end

  test "tour auto-starts for a new user and stops once onboarded" do
    get quiniela_path
    assert_match 'data-tour-auto-value="true"', response.body
    patch onboarding_path
    get quiniela_path
    assert_match 'data-tour-auto-value="false"', response.body
  end
end
