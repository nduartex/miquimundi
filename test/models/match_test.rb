require "test_helper"

class MatchTest < ActiveSupport::TestCase
  test "knockout? excludes group phase" do
    assert_not Match.new(phase: "group").knockout?
    assert Match.new(phase: "round_16").knockout?
    assert Match.new(phase: "final").knockout?
  end

  test "multiplier scales by phase" do
    assert_in_delta 1.0, Match.new(phase: "round_16").multiplier, 0.001
    assert_in_delta 1.5, Match.new(phase: "quarter").multiplier, 0.001
    assert_in_delta 2.0, Match.new(phase: "semi").multiplier, 0.001
    assert_in_delta 3.0, Match.new(phase: "final").multiplier, 0.001
  end

  test "locked? once kickoff has passed" do
    assert Match.new(kickoff_at: 1.hour.ago).locked?
    assert_not Match.new(kickoff_at: 1.hour.from_now).locked?
  end

  test "finished? requires both goals present" do
    assert_not Match.new(status: "finished").finished?
    assert Match.new(status: "finished", home_goals: 1, away_goals: 0).finished?
  end
end
