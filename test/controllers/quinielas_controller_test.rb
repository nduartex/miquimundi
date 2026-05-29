require "test_helper"

class QuinielasControllerTest < ActionDispatch::IntegrationTest
  def setup
    SeedLoader.call
    @user = User.create!(username: "tester")
    get restore_path(token: @user.access_token)
  end

  test "show renders the 4-step wizard with groups, thirds and locked knockouts" do
    get quiniela_path
    assert_response :success
    assert_select "h1", text: "Mi Quiniela"
    assert_match "Grupo A", response.body
    assert_match "8 mejores terceros", response.body         # thirds step
    assert_match "Eliminatorias bloqueadas", response.body   # knockout locked until groups end
    assert_match "Balón de Oro", response.body               # new awards available from the start
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

  test "knockout opens once groups finish and a kicked-off match is locked in the UI" do
    tournament = Tournament.current
    tournament.groups.each do |g|
      ts = g.teams.to_a
      GroupResult.create!(group: g, first_team: ts[0], second_team: ts[1])
    end
    m = tournament.matches.find_by(bracket_slot: "M73")
    pair = Team.joins(:group).where(groups: { tournament_id: tournament.id }).first(2)
    m.update!(home_team: pair[0], away_team: pair[1], kickoff_at: 1.hour.ago)

    get quiniela_path
    assert_response :success
    assert_no_match "Eliminatorias bloqueadas", response.body  # knockout open now
    assert_match "🔒 Cerrado", response.body                    # started match shows locked
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
