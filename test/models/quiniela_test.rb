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
end
