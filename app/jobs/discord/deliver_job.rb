module Discord
  # Performs the actual webhook POST off the request/sync path. No-op when the
  # target webhook isn't configured (dormant channel). Swallows delivery errors
  # — a Discord outage must never fail the job, and never re-raising keeps the
  # global error hook from looping on its own delivery failures.
  class DeliverJob < ApplicationJob
    queue_as :default

    # Stateless HTTP client; overridable in tests with a fake (no real client
    # shares mutable state, so a single instance is safe).
    class_attribute :client, instance_accessor: false, default: Discord::Client.new

    def perform(webhook_key, payload)
      url = Discord::Notifier.webhook_url(webhook_key)
      return if url.blank?

      self.class.client.post(url, payload)
    rescue Discord::Client::Error => e
      Rails.logger.warn("[discord] delivery failed (#{webhook_key}): #{e.message}")
    end
  end
end
