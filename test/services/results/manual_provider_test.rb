require "test_helper"

class Results::ManualProviderTest < ActiveSupport::TestCase
  def setup
    @tournament = Tournament.create!(name: "WC", year: 2026)
    @group = Group.create!(tournament: @tournament, name: "A")
    @t1 = Team.create!(group: @group, name: "T1", code: "T1")
    @t2 = Team.create!(group: @group, name: "T2", code: "T2")
    @match = Match.create!(tournament: @tournament, phase: "round_16",
                           home_team: @t1, away_team: @t2, status: "scheduled",
                           kickoff_at: 1.day.ago, bracket_slot: "R16-1")
  end

  test "applies group results and match scores from a hash" do
    data = {
      "group_results" => [ { "group" => "A", "first" => "T1", "second" => "T2" } ],
      "matches" => [ { "bracket_slot" => "R16-1", "home_goals" => 2, "away_goals" => 1 } ]
    }
    Results::ManualProvider.new(@tournament, data).apply!

    assert_equal @t1.id, GroupResult.find_by(group: @group).first_team_id
    @match.reload
    assert_equal 2, @match.home_goals
    assert_equal "finished", @match.status
  end
end
