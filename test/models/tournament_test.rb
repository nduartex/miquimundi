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

  test "late window is closed before kickoff" do
    @tournament.update!(locked_at: 1.day.from_now, late_deadline_at: 2.days.from_now)
    assert_not @tournament.late_window_open?
  end

  test "late window is open between kickoff and the deadline" do
    @tournament.update!(locked_at: 1.hour.ago, late_deadline_at: 1.day.from_now)
    assert @tournament.late_window_open?
  end

  test "late window closes once the deadline passes" do
    @tournament.update!(locked_at: 1.day.ago, late_deadline_at: 1.hour.ago)
    assert_not @tournament.late_window_open?
  end

  test "no late window without a deadline" do
    @tournament.update!(locked_at: 1.hour.ago, late_deadline_at: nil)
    assert_not @tournament.late_window_open?
  end
end
