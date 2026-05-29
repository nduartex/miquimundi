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

  def build_match(phase:, home:, away:, hg:, ag:, pen: nil)
    Match.create!(tournament: @tournament, phase: phase, home_team: home, away_team: away,
                  home_goals: hg, away_goals: ag, penalty_winner: pen,
                  status: "finished", kickoff_at: 1.day.ago)
  end

  test "exact score in round_16 scores 5" do
    m = build_match(phase: "round_16", home: @t1, away: @t2, hg: 2, ag: 1)
    MatchPrediction.create!(quiniela: @quiniela, match: m, pred_home: 2, pred_away: 1)
    ScoringService.new(@quiniela).call
    assert_equal 5, @quiniela.reload.total_points
    assert_equal 1, @quiniela.exact_hits
    assert_equal 1, @quiniela.match_hits
  end

  test "correct winner wrong score scores 2" do
    m = build_match(phase: "round_16", home: @t1, away: @t2, hg: 3, ag: 0)
    MatchPrediction.create!(quiniela: @quiniela, match: m, pred_home: 2, pred_away: 1)
    ScoringService.new(@quiniela).call
    assert_equal 2, @quiniela.reload.total_points
    assert_equal 0, @quiniela.exact_hits
    assert_equal 1, @quiniela.match_hits
  end

  test "quarter multiplier x1.5 on exact score yields 7" do
    m = build_match(phase: "quarter", home: @t1, away: @t2, hg: 1, ag: 0)
    MatchPrediction.create!(quiniela: @quiniela, match: m, pred_home: 1, pred_away: 0)
    ScoringService.new(@quiniela).call
    assert_equal 7, @quiniela.reload.total_points # floor(5 * 1.5) = 7
  end

  test "final multiplier x3 on exact score yields 24 with penalty" do
    m = build_match(phase: "final", home: @t1, away: @t2, hg: 0, ag: 0, pen: @t1)
    MatchPrediction.create!(quiniela: @quiniela, match: m, pred_home: 0, pred_away: 0, penalty_qualifier: @t1)
    ScoringService.new(@quiniela).call
    # exact 0-0 = 5, +3 penalty correct = 8, x3 = 24
    assert_equal 24, @quiniela.reload.total_points
  end

  test "correct penalty qualifier scores 3" do
    m = build_match(phase: "round_16", home: @t1, away: @t2, hg: 1, ag: 1, pen: @t2)
    MatchPrediction.create!(quiniela: @quiniela, match: m, pred_home: 0, pred_away: 0, penalty_qualifier: @t2)
    ScoringService.new(@quiniela).call
    # pred 0-0 is a draw -> no winner pts and not exact; penalty correct = 3
    assert_equal 3, @quiniela.reload.total_points
  end

  test "correct top scorer and top assists each score 10" do
    p1 = Player.create!(team: @t1, name: "Striker")
    p2 = Player.create!(team: @t2, name: "Playmaker")
    TournamentResult.create!(tournament: @tournament, top_scorer_player: p1, top_assists_player: p2)
    AwardPrediction.create!(quiniela: @quiniela, top_scorer_player: p1, top_assists_player: p2)
    ScoringService.new(@quiniela).call
    assert_equal 20, @quiniela.reload.total_points
  end

  test "only top scorer correct scores 10" do
    p1 = Player.create!(team: @t1, name: "Striker")
    p2 = Player.create!(team: @t2, name: "Playmaker")
    p3 = Player.create!(team: @t3, name: "Other")
    TournamentResult.create!(tournament: @tournament, top_scorer_player: p1, top_assists_player: p2)
    AwardPrediction.create!(quiniela: @quiniela, top_scorer_player: p1, top_assists_player: p3)
    ScoringService.new(@quiniela).call
    assert_equal 10, @quiniela.reload.total_points
  end
end
