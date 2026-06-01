require "test_helper"

class QuinielasControllerTest < ActionDispatch::IntegrationTest
  def setup
    SeedLoader.call
    @user = User.create!(username: "tester")
    get restore_path(token: @user.access_token)
  end

  test "shows the celebration modal only when the fase1 flag is present" do
    get quiniela_path(fase1: 1)
    assert_select "[data-controller='celebrate']"
    assert_match(/Completaste la primera fase/i, response.body)

    get quiniela_path
    assert_select "[data-controller='celebrate']", false
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
    assert_match "/flags/mx.png", response.body
    assert_select "li[data-group-order-target='item']"                       # sortable rows
    assert_select "[data-action='pointerdown->group-order#start']"           # touch/mouse drag handle
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

  test "lists all achievements (earned and locked) and offers to share when any is unlocked" do
    q = @user.quinielas.find_or_create_by!(tournament: Tournament.current)
    q.achievements.create!(key: "profeta", earned_at: Time.current)
    get quiniela_path
    assert_match "Mis logros", response.body
    assert_match "Profeta", response.body                       # unlocked
    assert_match "Nostradamus", response.body                   # locked but still listed (greyed)
    assert_select "[data-action='achievements-share#share']"     # share button present
  end

  test "hides the share button when no achievement is unlocked" do
    @user.quinielas.find_or_create_by!(tournament: Tournament.current)
    get quiniela_path
    assert_match "Mis logros", response.body
    assert_match "Nostradamus", response.body                   # locked badges still listed
    assert_select "[data-action='achievements-share#share']", false
    assert_match "Desbloqueá tu primer logro", response.body
  end

  test "enables the prediction share card when the first part is complete" do
    q = @user.quinielas.find_or_create_by!(tournament: Tournament.current)
    complete_first_part!(q)
    q.update!(submitted_at: Time.current)
    get quiniela_path
    assert_select "[data-controller~='share-card']"
    assert_select "[data-action='share-card#share']"            # enabled button
    assert_select "[data-share-card-target='data']"             # embedded prediction JSON
    assert_match "MI PREDICCIÓN", response.body
  end

  test "disables the prediction share card with a hint when incomplete" do
    q = @user.quinielas.find_or_create_by!(tournament: Tournament.current)
    q.update!(submitted_at: Time.current)
    get quiniela_path
    assert_select "[data-controller~='share-card']"
    assert_select "[data-action='share-card#share']", false     # no enabled button
    assert_select "button[disabled]"
    assert_match "para generar tu imagen", response.body
  end

  test "no share-card button before submitting" do
    @user.quinielas.find_or_create_by!(tournament: Tournament.current).update!(submitted_at: nil)
    get quiniela_path
    assert_select "[data-controller~='share-card']", false
  end

  private

  def complete_first_part!(quiniela)
    Tournament.current.groups.each do |g|
      t = g.teams.to_a
      quiniela.group_predictions.create!(
        group: g, first_team: t[0], second_team: t[1], third_team: t[2], fourth_team: t[3]
      )
    end
    quiniela.update!(best_third_groups: %w[A B C D E F G H])
    player = Player.first
    quiniela.create_award_prediction!(
      balon_oro_player: player, bota_oro_player: player, guante_oro_player: player,
      young_player: player, fair_play_team: Team.first
    )
  end
end
