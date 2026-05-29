require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seed loader is idempotent and builds 12 groups / 48 teams" do
    SeedLoader.call
    SeedLoader.call # second run should not duplicate
    tournament = Tournament.find_by(year: 2026)
    assert_equal 12, tournament.groups.count
    assert_equal 48, Team.joins(:group).where(groups: { tournament_id: tournament.id }).count
    assert_equal 15, tournament.matches.count
    assert tournament.matches.where(phase: "final").one?
  end
end
