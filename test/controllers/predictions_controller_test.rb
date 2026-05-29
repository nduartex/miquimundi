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
end
