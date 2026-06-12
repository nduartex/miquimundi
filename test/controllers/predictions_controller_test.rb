require "test_helper"

class PredictionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    SeedLoader.call
    @tournament = Tournament.current
    @group = @tournament.groups.find_by(name: "A")
    @teams = @group.teams.to_a
    @user = User.create!(username: "tester")
    get restore_path(token: @user.access_token) # log in via personal link
  end

  # Full first part for the seeded tournament. `thirds` overridable to test capping.
  def complete_first_part_params(thirds: %w[A B C D E F G H])
    player = Player.first
    team = Team.first
    {
      group_predictions: @tournament.groups.order(:name).each_with_object({}) do |g, h|
        t = g.teams.to_a
        h[g.id.to_s] = {
          first_team_id: t[0].id, second_team_id: t[1].id,
          third_team_id: t[2].id, fourth_team_id: t[3].id
        }
      end,
      best_third_groups: thirds,
      award_prediction: {
        balon_oro_player_id: player.id, bota_oro_player_id: player.id,
        guante_oro_player_id: player.id, young_player_id: player.id,
        fair_play_team_id: team.id
      }
    }
  end

  test "a complete first part saves records and submits" do
    post quiniela_predictions_path, params: complete_first_part_params
    quiniela = @user.quinielas.find_by(tournament: @tournament)
    assert_not_nil quiniela
    assert quiniela.submitted?
    gp = quiniela.group_predictions.find_by(group: @group)
    assert_equal @teams[0].id, gp.first_team_id
  end

  test "a complete first part stores the full 1-4 group ranking" do
    post quiniela_predictions_path, params: complete_first_part_params
    gp = @user.quinielas.find_by(tournament: @tournament).group_predictions.find_by(group: @group)
    assert_equal [ @teams[0].id, @teams[1].id, @teams[2].id, @teams[3].id ], gp.ranked_team_ids
  end

  test "best-third group picks are capped at 8" do
    post quiniela_predictions_path, params: complete_first_part_params(thirds: %w[A B C D E F G H I])
    q = @user.quinielas.find_by(tournament: @tournament)
    assert_equal 8, q.best_third_groups.size
    assert_equal %w[A B C D E F G H], q.best_third_groups
  end

  test "an incomplete first part is rejected: nothing saved, not submitted, alert shown" do
    post quiniela_predictions_path, params: {
      group_predictions: { @group.id.to_s => { first_team_id: @teams[0].id, second_team_id: @teams[1].id } }
    }
    q = @user.quinielas.find_by(tournament: @tournament)
    assert_not_nil q                       # quiniela shell exists (created on entry)
    assert_not q.submitted?                # gate rolled back submitted_at
    assert_equal 0, q.group_predictions.count # partial save rolled back too
    assert_match(/Completa las 3 fases/, flash[:alert])
  end

  test "pre-lock, omitting best_third_groups is treated as deselect-all and rejected" do
    post quiniela_predictions_path, params: complete_first_part_params
    q = @user.quinielas.find_by(tournament: @tournament)
    assert_equal 8, q.best_third_groups.size

    # Re-submit without the thirds param (every checkbox unchecked). Treated as a
    # clear, so the first part is incomplete and the gate rejects the save (rather
    # than silently keeping the prior 8 and re-submitting).
    post quiniela_predictions_path, params: complete_first_part_params.except(:best_third_groups)
    assert_match(/Completa las 3 fases/, flash[:alert])
    assert_equal 8, q.reload.best_third_groups.size # prior valid state intact (rolled back)
  end

  test "group predictions stay editable even after the tournament starts (date lock disabled)" do
    post quiniela_predictions_path, params: complete_first_part_params
    gp = @user.quinielas.find_by(tournament: @tournament).group_predictions.find_by(group: @group)
    assert_equal @teams[0].id, gp.first_team_id

    @tournament.update!(locked_at: 1.day.ago) # World Cup has started, but the date lock is disabled
    # Re-submit a complete first part with group A's top two swapped.
    edited = complete_first_part_params
    edited[:group_predictions][@group.id.to_s].merge!(
      first_team_id: @teams[2].id, second_team_id: @teams[3].id,
      third_team_id: @teams[0].id, fourth_team_id: @teams[1].id
    )
    post quiniela_predictions_path, params: edited
    assert_equal @teams[2].id, gp.reload.first_team_id # editable: new value saved
  end

  test "once the first part is complete, a knockout-only save is not gate-blocked after kickoff" do
    post quiniela_predictions_path, params: complete_first_part_params # first part completed
    @tournament.update!(locked_at: 1.day.ago) # World Cup started (date lock disabled, but irrelevant now)
    post quiniela_predictions_path, params: {} # knockout-only save: nothing to add, must not be gate-blocked
    assert @user.quinielas.find_by(tournament: @tournament).submitted?
  end

  test "knockout score predictions are ignored while the stage is locked" do
    m = @tournament.matches.find_by(phase: "round_32")
    post quiniela_predictions_path, params: {
      match_predictions: { m.id.to_s => { pred_home: 2, pred_away: 0 } }
    }
    q = @user.quinielas.find_by(tournament: @tournament)
    assert_nil q.match_predictions.find_by(match_id: m.id) # locked: not saved
  end

  test "first time completing the first part sets the milestone and redirects with the celebration flag" do
    post quiniela_predictions_path, params: complete_first_part_params
    q = @user.quinielas.find_by(tournament: @tournament)
    assert_not_nil q.first_part_completed_at
    assert_redirected_to quiniela_path(fase1: 1)
  end

  test "completing again keeps the original milestone and skips the celebration" do
    post quiniela_predictions_path, params: complete_first_part_params
    q = @user.quinielas.find_by(tournament: @tournament)
    first_ts = q.first_part_completed_at
    assert_not_nil first_ts

    travel 1.minute do
      post quiniela_predictions_path, params: complete_first_part_params
    end
    assert_redirected_to quiniela_path
    assert_equal first_ts.to_i, q.reload.first_part_completed_at.to_i
  end

  test "earning an achievement on save redirects with the logros flag" do
    post quiniela_predictions_path, params: complete_first_part_params
    q = @user.quinielas.find_by(tournament: @tournament)
    q.update!(worst_rank: 15) # simulate having been far down the ranking

    post quiniela_predictions_path, params: complete_first_part_params
    assert q.reload.achievements.exists?(key: "remontada")
    assert_match(/logros=remontada/, @response.headers["Location"].to_s)
  end
end
