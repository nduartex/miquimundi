require "test_helper"

module Discord
  class NotifierTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    # [webhook_key, payload] of the most recent enqueued delivery.
    def last_delivery
      enqueued_jobs.last[:args]
    end

    test "goal enqueues a goals delivery with scorer and reconciled score" do
      Notifier.goal(scorer: "Messi", scoring_team: "Argentina", home_team: "Argentina",
                    away_team: "Francia", home_goals: 1, away_goals: 0, minute: "23'",
                    penalty: false, own_goal: false)
      key, payload = last_delivery
      assert_equal "goals", key
      assert_equal "@everyone", payload["content"], "goals must ping the server"
      assert_equal [ "everyone" ], payload.dig("allowed_mentions", "parse")
      embed = payload["embeds"].first
      assert_equal "⚽ ¡GOL de Argentina!", embed["title"]
      assert_includes embed["description"], "Messi"
      assert_includes embed["description"], "Argentina 1 - 0 Francia"
    end

    test "penalty goals say 'de penal'" do
      Notifier.goal(scorer: "Kane", scoring_team: "Inglaterra", home_team: "Inglaterra",
                    away_team: "Brasil", home_goals: 1, away_goals: 0, minute: "10'",
                    penalty: true, own_goal: false)
      assert_includes last_delivery[1]["embeds"].first["description"], "de penal"
    end

    test "own goals are credited to the benefiting team" do
      Notifier.goal(scorer: "Rival", scoring_team: "Brasil", home_team: "Inglaterra",
                    away_team: "Brasil", home_goals: 1, away_goals: 1, minute: "50'",
                    penalty: false, own_goal: true)
      embed = last_delivery[1]["embeds"].first
      assert_equal "⚽ Gol en contra", embed["title"]
      assert_includes embed["description"], "favorece a Brasil"
    end

    test "report_error targets the errors webhook" do
      Notifier.report_error(RuntimeError.new("boom"), context: { job: "X" })
      key, payload = last_delivery
      assert_equal "errors", key
      assert_nil payload["content"], "the errors channel must not ping @everyone"
      assert_includes payload["embeds"].first["title"], "RuntimeError"
    end

    test "report_error never raises and never enqueues on a bad argument" do
      assert_no_enqueued_jobs do
        assert_nothing_raised { Notifier.report_error(nil) }
      end
    end

    test "webhook_url falls back to ENV and is nil when unset" do
      assert_nil Notifier.webhook_url(:goals)
      ENV["DISCORD_GOALS_WEBHOOK_URL"] = "https://example.test/hook"
      assert_equal "https://example.test/hook", Notifier.webhook_url(:goals)
    ensure
      ENV.delete("DISCORD_GOALS_WEBHOOK_URL")
    end
  end
end
