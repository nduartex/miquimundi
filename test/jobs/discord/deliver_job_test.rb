require "test_helper"

module Discord
  class DeliverJobTest < ActiveSupport::TestCase
    def setup
      @original_client = DeliverJob.client
    end

    def teardown
      DeliverJob.client = @original_client
      ENV.delete("DISCORD_GOALS_WEBHOOK_URL")
    end

    def fake_client(&post)
      Object.new.tap { |c| c.define_singleton_method(:post, &post) }
    end

    test "no-op when the webhook url is blank" do
      posted = false
      DeliverJob.client = fake_client { |*| posted = true }
      DeliverJob.perform_now("errors", { "embeds" => [] }) # errors webhook unset
      assert_not posted, "must not POST when the webhook is dormant"
    end

    test "posts to the resolved url when configured" do
      posted = []
      DeliverJob.client = fake_client { |url, payload| posted << [ url, payload ] }
      ENV["DISCORD_GOALS_WEBHOOK_URL"] = "https://hook.test/x"
      DeliverJob.perform_now("goals", { "embeds" => [ { "title" => "hi" } ] })
      assert_equal 1, posted.size
      assert_equal "https://hook.test/x", posted.first[0]
      assert_equal "hi", posted.first[1]["embeds"].first["title"]
    end

    test "swallows client errors instead of failing the job" do
      DeliverJob.client = fake_client { |*| raise Discord::Client::Error, "discord down" }
      ENV["DISCORD_GOALS_WEBHOOK_URL"] = "https://hook.test/x"
      assert_nothing_raised { DeliverJob.perform_now("goals", {}) }
    end
  end
end
