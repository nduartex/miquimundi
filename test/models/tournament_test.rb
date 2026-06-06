require "test_helper"

class TournamentTest < ActiveSupport::TestCase
  def setup
    @tournament = Tournament.create!(name: "WC", year: 2026)
  end

  test "not finished without a final match" do
    assert_not @tournament.finished?
  end

  test "not finished while the final is still scheduled" do
    @tournament.matches.create!(phase: "final", status: "scheduled")
    assert_not @tournament.finished?
  end

  test "finished once the final has a result" do
    @tournament.matches.create!(phase: "final", status: "finished", home_goals: 2, away_goals: 1)
    assert @tournament.finished?
  end
end
