require "test_helper"

class QuinielaTest < ActiveSupport::TestCase
  def setup
    SeedLoader.call
    @tournament = Tournament.current
    @user = User.create!(username: "modeltester")
    @quiniela = @user.quinielas.create!(tournament: @tournament)
  end

  # Fill all three phases so the quiniela is a complete "first part".
  def complete!
    @tournament.groups.each do |g|
      t = g.teams.to_a
      @quiniela.group_predictions.create!(
        group: g, first_team: t[0], second_team: t[1], third_team: t[2], fourth_team: t[3]
      )
    end
    @quiniela.update!(best_third_groups: %w[A B C D E F G H])
    player = Player.first
    team = Team.first
    @quiniela.create_award_prediction!(
      balon_oro_player: player, bota_oro_player: player, guante_oro_player: player,
      young_player: player, fair_play_team: team
    )
    @quiniela.reload
  end

  test "defaults counters to zero" do
    q = Quiniela.new
    assert_equal 0, q.total_points
    assert_equal 0, q.exact_hits
    assert_equal 0, q.match_hits
  end

  test "submitted? reflects submitted_at" do
    assert_not Quiniela.new.submitted?
    assert Quiniela.new(submitted_at: Time.current).submitted?
  end

  test "a quiniela gets a share_token on create" do
    assert @quiniela.share_token.present?
  end

  test "first_part_complete? is true when all three phases are filled" do
    complete!
    assert @quiniela.first_part_complete?
    assert_empty @quiniela.first_part_missing
  end

  test "incomplete groups make first_part incomplete" do
    complete!
    @quiniela.group_predictions.first.destroy
    assert_not @quiniela.reload.first_part_complete?
  end

  test "fewer than 8 thirds make first_part incomplete" do
    complete!
    @quiniela.update!(best_third_groups: %w[A B C])
    assert_not @quiniela.first_part_complete?
    assert(@quiniela.first_part_missing.any? { |m| m.include?("terceros") })
  end

  test "missing an award makes first_part incomplete" do
    complete!
    @quiniela.award_prediction.update!(fair_play_team_id: nil)
    assert_not @quiniela.reload.first_part_complete?
    assert(@quiniela.first_part_missing.any? { |m| m.include?("premios") })
  end

  test "late? only when the first part was completed after kickoff" do
    @tournament.update!(locked_at: 1.hour.ago)
    assert_not @quiniela.late? # never completed

    @quiniela.update!(first_part_completed_at: 2.hours.ago)
    assert_not @quiniela.late? # completed before kickoff

    @quiniela.update!(first_part_completed_at: 30.minutes.ago)
    assert @quiniela.late? # completed during the late window
  end

  test "first part is editable before kickoff" do
    @tournament.update!(locked_at: 1.day.from_now)
    assert @quiniela.first_part_editable?
  end

  test "first part stays editable in the late window only for never-completed quinielas" do
    @tournament.update!(locked_at: 1.hour.ago, late_deadline_at: 1.day.from_now)
    assert @quiniela.first_part_editable?

    @quiniela.update!(first_part_completed_at: 30.minutes.ago)
    assert_not @quiniela.first_part_editable?
  end

  test "first part is not editable once the late deadline passes" do
    @tournament.update!(locked_at: 1.day.ago, late_deadline_at: 1.hour.ago)
    assert_not @quiniela.first_part_editable?
  end

  test "current_rank is 1 for the top scorer and increases below" do
    @quiniela.update!(total_points: 100)
    other = User.create!(username: "second").quinielas.create!(tournament: @tournament, total_points: 40)
    assert_equal 1, @quiniela.current_rank
    assert_equal 2, other.current_rank
  end

  test "champion_correct? compares predicted final winner to the real one" do
    final = @tournament.matches.find_by(phase: "final")
    teams = Team.limit(2).to_a
    final.update!(home_team: teams[0], away_team: teams[1],
                  home_goals: 2, away_goals: 1, status: "finished")
    @quiniela.match_predictions.create!(match: final, pred_home: 3, pred_away: 0)
    assert @quiniela.champion_correct?           # predicted home wins == real home wins

    @quiniela.match_predictions.find_by(match: final).update!(pred_home: 0, pred_away: 3)
    assert_not @quiniela.reload.champion_correct? # predicted away, home won
  end
end
