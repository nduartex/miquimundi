require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seed loader is idempotent and builds 12 groups / 48 teams" do
    SeedLoader.call
    SeedLoader.call # second run should not duplicate
    tournament = Tournament.find_by(year: 2026)
    assert_equal 12, tournament.groups.count
    assert_equal 48, Team.joins(:group).where(groups: { tournament_id: tournament.id }).count
    assert_equal 32, tournament.matches.count
    assert tournament.matches.where(phase: "final").one?
  end

  test "seeds the full official 2026 knockout bracket with wiring" do
    SeedLoader.call
    tournament = Tournament.find_by(year: 2026)
    assert_equal 16, tournament.matches.where(phase: "round_32").count
    assert_equal 8,  tournament.matches.where(phase: "round_16").count
    assert_equal 4,  tournament.matches.where(phase: "quarter").count
    assert_equal 2,  tournament.matches.where(phase: "semi").count
    assert_equal 1,  tournament.matches.where(phase: "third_place").count
    assert_equal 1,  tournament.matches.where(phase: "final").count

    # Bracket wiring + cruce labels
    m73 = tournament.matches.find_by(bracket_slot: "M73")
    assert_equal "2A", m73.home_label
    assert_equal "2B", m73.away_label
    assert_equal "M90", m73.advances_to

    final = tournament.matches.find_by(phase: "final")
    assert_equal "Gan. 101", final.home_label
    assert_nil final.advances_to
  end
end
