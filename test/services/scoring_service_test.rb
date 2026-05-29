require "test_helper"

class ScoringServiceTest < ActiveSupport::TestCase
  def setup
    @tournament = Tournament.create!(name: "WC", year: 2026)
    @group = Group.create!(tournament: @tournament, name: "A")
    @t1 = Team.create!(group: @group, name: "T1")
    @t2 = Team.create!(group: @group, name: "T2")
    @t3 = Team.create!(group: @group, name: "T3")
    GroupResult.create!(group: @group, first_team: @t1, second_team: @t2)
    @user = User.create!(email: "p@x.com")
    @quiniela = Quiniela.create!(user: @user, tournament: @tournament)
  end

  test "both teams correct and in exact order scores 3+3+2" do
    GroupPrediction.create!(quiniela: @quiniela, group: @group, first_team: @t1, second_team: @t2)
    ScoringService.new(@quiniela).call
    assert_equal 8, @quiniela.reload.total_points
  end

  test "both teams correct but wrong order scores 3+3" do
    GroupPrediction.create!(quiniela: @quiniela, group: @group, first_team: @t2, second_team: @t1)
    ScoringService.new(@quiniela).call
    assert_equal 6, @quiniela.reload.total_points
  end

  test "one team correct scores 3" do
    GroupPrediction.create!(quiniela: @quiniela, group: @group, first_team: @t1, second_team: @t3)
    ScoringService.new(@quiniela).call
    assert_equal 3, @quiniela.reload.total_points
  end
end
