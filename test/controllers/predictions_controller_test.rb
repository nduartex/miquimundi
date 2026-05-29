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

  test "saving stores third_group choice for a Round of 32 third slot" do
    m74 = @tournament.matches.find_by(bracket_slot: "M74") # away slot is a 3rd-place candidate
    post quiniela_predictions_path, params: {
      match_predictions: { m74.id.to_s => { pred_home: 2, pred_away: 0, third_group: "C" } }
    }
    mp = @user.quinielas.find_by(tournament: @tournament).match_predictions.find_by(match_id: m74.id)
    assert_equal "C", mp.third_group
  end
end
