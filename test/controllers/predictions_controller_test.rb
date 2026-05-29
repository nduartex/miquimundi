require "test_helper"

class PredictionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    SeedLoader.call
    @tournament = Tournament.current
    @group = @tournament.groups.find_by(name: "A")
    @teams = @group.teams.to_a
    @user = User.create!(email: "p@x.com")
    post session_path, params: { email: @user.email }
  end

  test "saving group predictions creates records and a quiniela" do
    post quiniela_predictions_path, params: {
      group_predictions: {
        @group.id.to_s => { first_team_id: @teams[0].id, second_team_id: @teams[1].id }
      }
    }
    quiniela = @user.quinielas.find_by(tournament: @tournament)
    assert_not_nil quiniela
    gp = quiniela.group_predictions.find_by(group: @group)
    assert_equal @teams[0].id, gp.first_team_id
  end

  test "saving sets submitted_at and triggers scoring" do
    post quiniela_predictions_path, params: {
      group_predictions: { @group.id.to_s => { first_team_id: @teams[0].id, second_team_id: @teams[1].id } }
    }
    assert @user.quinielas.find_by(tournament: @tournament).submitted?
  end

  test "saving stores the full 1-4 group ranking" do
    post quiniela_predictions_path, params: {
      group_predictions: {
        @group.id.to_s => {
          first_team_id: @teams[0].id, second_team_id: @teams[1].id,
          third_team_id: @teams[2].id, fourth_team_id: @teams[3].id
        }
      }
    }
    gp = @user.quinielas.find_by(tournament: @tournament).group_predictions.find_by(group: @group)
    assert_equal [@teams[0].id, @teams[1].id, @teams[2].id, @teams[3].id], gp.ranked_team_ids
  end

  test "saving stores the 8 best-third group picks (capped at 8)" do
    letters = %w[A B C D E F G H I]  # 9 sent
    post quiniela_predictions_path, params: { best_third_groups: letters }
    q = @user.quinielas.find_by(tournament: @tournament)
    assert_equal 8, q.best_third_groups.size
    assert_equal %w[A B C D E F G H], q.best_third_groups
  end

  test "group predictions are frozen and not overwritten once the tournament starts" do
    post quiniela_predictions_path, params: {
      group_predictions: { @group.id.to_s => { first_team_id: @teams[0].id, second_team_id: @teams[1].id } }
    }
    gp = @user.quinielas.find_by(tournament: @tournament).group_predictions.find_by(group: @group)
    assert_equal @teams[0].id, gp.first_team_id

    @tournament.update!(locked_at: 1.day.ago) # World Cup has started
    post quiniela_predictions_path, params: {
      group_predictions: { @group.id.to_s => { first_team_id: @teams[2].id, second_team_id: @teams[3].id } }
    }
    assert_equal @teams[0].id, gp.reload.first_team_id # original kept, not overwritten
  end

  test "knockout score predictions are ignored while the stage is locked" do
    m = @tournament.matches.find_by(phase: "round_32")
    post quiniela_predictions_path, params: {
      match_predictions: { m.id.to_s => { pred_home: 2, pred_away: 0 } }
    }
    q = @user.quinielas.find_by(tournament: @tournament)
    assert_nil q.match_predictions.find_by(match_id: m.id) # locked: not saved
  end
end
