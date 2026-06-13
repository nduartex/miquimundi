require "test_helper"

module Discord
  class PrematchAlertsJobTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    def setup
      @tournament = Tournament.create!(name: "WC", year: 2026)
      @group = Group.create!(tournament: @tournament, name: "A")
      @home = Team.create!(group: @group, name: "Alfa", code: "AAA")
      @away = Team.create!(group: @group, name: "Beta", code: "BBB")
      @home2 = Team.create!(group: @group, name: "Gama", code: "CCC")
      @away2 = Team.create!(group: @group, name: "Delta", code: "DDD")
    end

    def match_at(minutes, home: @home, away: @away, **attrs)
      Match.create!(tournament: @tournament, phase: "group", home_team: home, away_team: away,
                    status: "scheduled", kickoff_at: minutes.minutes.from_now, **attrs)
    end

    test "sends the ~20 minute reminder exactly once" do
      m = match_at(20)
      assert_enqueued_with(job: Discord::DeliverJob) { PrematchAlertsJob.perform_now }
      assert_equal 20, m.reload.prematch_alert_min

      assert_no_enqueued_jobs only: Discord::DeliverJob do
        PrematchAlertsJob.perform_now
      end
    end

    test "sends the ~10 minute reminder after the 20 was already sent" do
      m = match_at(10, prematch_alert_min: 20)
      assert_enqueued_with(job: Discord::DeliverJob) { PrematchAlertsJob.perform_now }
      assert_equal 10, m.reload.prematch_alert_min
    end

    test "ignores matches outside the window or not scheduled" do
      match_at(40)                                              # too far out
      match_at(5, home: @home2, away: @away2, status: "live")   # already kicked off
      assert_no_enqueued_jobs only: Discord::DeliverJob do
        PrematchAlertsJob.perform_now
      end
    end

    test "a skipped run collapses to a single ~10 alert" do
      m = match_at(9)              # jumped past the 20 window straight into the 10 one
      assert_enqueued_jobs 1, only: Discord::DeliverJob do
        PrematchAlertsJob.perform_now
      end
      assert_equal 10, m.reload.prematch_alert_min
    end
  end
end
