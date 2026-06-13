require "test_helper"

# Public live-data pages fed by the ESPN sync: standings, scorers, calendar
# enrichment and the per-group live frame used by the quiniela modal.
class LiveDataTest < ActionDispatch::IntegrationTest
  def setup
    @tournament = Tournament.create!(name: "WC", year: 2026)
    @group = Group.create!(tournament: @tournament, name: "A")
    @mex = Team.create!(group: @group, name: "México", code: "MEX")
    @rsa = Team.create!(group: @group, name: "Sudáfrica", code: "RSA")
    @match = Match.create!(tournament: @tournament, phase: "group", home_team: @mex,
                           away_team: @rsa, status: "finished", home_goals: 2, away_goals: 0,
                           kickoff_at: Time.utc(2026, 6, 11, 19), espn_id: "760415")
    @match.goals.create!(team: @mex, player_name: "Julián Quiñones", minute: "9'", sort_order: 0)
    @match.goals.create!(team: @mex, player_name: "Raúl Jiménez", minute: "67'", sort_order: 1)
    GroupStanding.create!(group: @group, team: @mex, played: 1, wins: 1, points: 3,
                          goals_for: 2, goal_difference: 2, rank: 1)
    GroupStanding.create!(group: @group, team: @rsa, played: 1, losses: 1, points: 0,
                          goals_for: 0, goals_against: 2, goal_difference: -2, rank: 4)
  end

  test "posiciones renders every group table with ranks" do
    get standings_path
    assert_response :success
    assert_match "Grupo A", response.body
    assert_match "México", response.body
  end

  test "posiciones projects a live match and shows the live banner" do
    aus = Team.create!(group: @group, name: "Australia", code: "AUS")
    tur = Team.create!(group: @group, name: "Turquía", code: "TUR")
    # México 0 official; a live 1-0 should project México to 3 pts, 1st.
    Match.create!(tournament: @tournament, phase: "group", home_team: @mex, away_team: aus,
                  status: "live", home_goals: 1, away_goals: 0, kickoff_at: 1.hour.ago)
    GroupStanding.where(group: @group).update_all(played: 0, points: 0, wins: 0,
                                                  goals_for: 0, goals_against: 0, goal_difference: 0, rank: nil)
    get standings_path
    assert_response :success
    assert_match "proyección provisional", response.body
    assert_match "auto-refresh", response.body
    assert_match "turbo-refresh-method", response.body
  end

  test "goleadores lists scorers with goal counts, excluding own goals" do
    @match.goals.create!(team: @mex, player_name: "Rival En Contra", minute: "80'",
                         own_goal: true, sort_order: 2)
    get scorers_path
    assert_response :success
    assert_match "Julián Quiñones", response.body
    assert_no_match "Rival En Contra", response.body
  end

  test "calendario shows the synced score and goal authors" do
    get calendar_path
    assert_response :success
    assert_match "2–0", response.body
    assert_match "Quiñones", response.body
    assert_match "Final", response.body
  end

  test "group live frame is public and hides the prediction block when logged out" do
    get group_live_path(@group)
    assert_response :success
    assert_match "turbo-frame", response.body
    assert_match "México", response.body
    assert_no_match "Tu pronóstico", response.body
  end

  test "shared quiniela page never shows the live modal (it would leak the visitor's prediction)" do
    owner = User.create!(username: "duenia_fc")
    quiniela = Quiniela.create!(user: owner, tournament: @tournament)
    get shared_quiniela_path(token: quiniela.share_token)
    assert_response :success
    assert_no_match "ver en vivo", response.body
    assert_no_match "group-live", response.body
  end

  test "group live frame compares against the signed-in user's prediction" do
    user = User.create!(username: "nelson_fc")
    quiniela = Quiniela.create!(user: user, tournament: @tournament)
    GroupPrediction.create!(quiniela: quiniela, group: @group,
                            first_team: @mex, second_team: @rsa)
    get restore_path(token: user.access_token) # log in via personal link
    get group_live_path(@group)
    assert_response :success
    assert_match "Tu pronóstico", response.body
    assert_match "✓ va ahí", response.body # MEX predicted 1st and currently 1st
  end
end
