require "test_helper"

class ScoringServiceTest < ActiveSupport::TestCase
  def setup
    @tournament = Tournament.create!(name: "WC", year: 2026)
    @group = Group.create!(tournament: @tournament, name: "A")
    @t1 = Team.create!(group: @group, name: "T1")
    @t2 = Team.create!(group: @group, name: "T2")
    @t3 = Team.create!(group: @group, name: "T3")
    GroupResult.create!(group: @group, first_team: @t1, second_team: @t2)
    @user = User.create!(username: "player1")
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

  test "round_32 exact score scores 5 (x1 multiplier)" do
    m = build_match(phase: "round_32", home: @t1, away: @t2, hg: 0, ag: 2)
    MatchPrediction.create!(quiniela: @quiniela, match: m, pred_home: 0, pred_away: 2)
    ScoringService.new(@quiniela).call
    assert_equal 5, @quiniela.reload.total_points
  end

  test "third_place exact score scores 5 (x1 multiplier)" do
    m = build_match(phase: "third_place", home: @t1, away: @t2, hg: 3, ag: 1)
    MatchPrediction.create!(quiniela: @quiniela, match: m, pred_home: 3, pred_away: 1)
    ScoringService.new(@quiniela).call
    assert_equal 5, @quiniela.reload.total_points
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

  test "all five individual awards score their points" do
    balon = Player.create!(team: @t1, name: "Best")
    bota  = Player.create!(team: @t2, name: "Scorer")
    guante = Player.create!(team: @t3, name: "Keeper")
    young = Player.create!(team: @t1, name: "Kid")
    TournamentResult.create!(tournament: @tournament, balon_oro_player: balon, bota_oro_player: bota,
                             guante_oro_player: guante, young_player: young, fair_play_team: @t2)
    AwardPrediction.create!(quiniela: @quiniela, balon_oro_player: balon, bota_oro_player: bota,
                            guante_oro_player: guante, young_player: young, fair_play_team: @t2)
    ScoringService.new(@quiniela).call
    assert_equal 10 + 10 + 8 + 6 + 5, @quiniela.reload.total_points # 39
  end

  test "partial awards: only balón de oro and fair play correct" do
    balon = Player.create!(team: @t1, name: "Best")
    other = Player.create!(team: @t2, name: "Other")
    TournamentResult.create!(tournament: @tournament, balon_oro_player: balon,
                             bota_oro_player: other, fair_play_team: @t1)
    AwardPrediction.create!(quiniela: @quiniela, balon_oro_player: balon,
                            bota_oro_player: Player.create!(team: @t3, name: "Wrong"), fair_play_team: @t1)
    ScoringService.new(@quiniela).call
    assert_equal 10 + 5, @quiniela.reload.total_points # balón 10 + fair play 5
  end

  test "call is idempotent — running twice does not double points" do
    GroupPrediction.create!(quiniela: @quiniela, group: @group, first_team: @t1, second_team: @t2)
    m = build_match(phase: "round_16", home: @t1, away: @t2, hg: 2, ag: 1)
    MatchPrediction.create!(quiniela: @quiniela, match: m, pred_home: 2, pred_away: 1)

    ScoringService.new(@quiniela).call
    first = @quiniela.reload.total_points
    ScoringService.new(@quiniela).call
    assert_equal first, @quiniela.reload.total_points
    assert_equal 13, first # group exact 8 + round_16 exact 5
  end

  test "non-finished matches are skipped" do
    m = Match.create!(tournament: @tournament, phase: "round_16", home_team: @t1, away_team: @t2,
                      status: "scheduled", kickoff_at: 1.day.from_now)
    MatchPrediction.create!(quiniela: @quiniela, match: m, pred_home: 1, pred_away: 0)
    ScoringService.new(@quiniela).call
    assert_equal 0, @quiniela.reload.total_points
  end

  test "penalty-only correctness does not increment match_hits" do
    m = build_match(phase: "round_16", home: @t1, away: @t2, hg: 1, ag: 1, pen: @t2)
    MatchPrediction.create!(quiniela: @quiniela, match: m, pred_home: 0, pred_away: 0, penalty_qualifier: @t2)
    ScoringService.new(@quiniela).call
    @quiniela.reload
    assert_equal 3, @quiniela.total_points
    assert_equal 0, @quiniela.match_hits
    assert_equal 0, @quiniela.exact_hits
  end

  test "persists points_earned on individual predictions" do
    gp = GroupPrediction.create!(quiniela: @quiniela, group: @group, first_team: @t1, second_team: @t2)
    ScoringService.new(@quiniela).call
    assert_equal 8, gp.reload.points_earned
  end

  test "correct best-third nomination scores 3" do
    @t3.update!(code: "T3")
    GroupPrediction.create!(quiniela: @quiniela, group: @group,
                            first_team: @t1, second_team: @t2, third_team: @t3)
    @quiniela.update!(best_third_groups: ["A"])
    TournamentResult.create!(tournament: @tournament, qualified_third_codes: ["T3"])
    ScoringService.new(@quiniela).call
    # group exact-order 8 + best third 3
    assert_equal 11, @quiniela.reload.total_points
  end

  test "best-third nomination that did not qualify scores 0 extra" do
    @t3.update!(code: "T3")
    GroupPrediction.create!(quiniela: @quiniela, group: @group,
                            first_team: @t1, second_team: @t2, third_team: @t3)
    @quiniela.update!(best_third_groups: ["A"])
    TournamentResult.create!(tournament: @tournament, qualified_third_codes: ["OTHER"])
    ScoringService.new(@quiniela).call
    assert_equal 8, @quiniela.reload.total_points # only the group points
  end
end
