module Discord
  # Runs every minute via Solid Queue recurring. Sends a Discord reminder ~20
  # and ~10 minutes before each scheduled match. prematch_alert_min stores the
  # smallest threshold already sent (nil = none), so each reminder fires once and
  # a skipped run collapses safely to a single, accurate alert.
  class PrematchAlertsJob < ApplicationJob
    queue_as :default
    limits_concurrency to: 1, key: "discord_prematch_alerts"

    LEAD_MINUTES = [ 20, 10 ].freeze

    def perform
      tournament = Tournament.current
      return unless tournament

      upcoming = tournament.matches.where(status: "scheduled")
                           .where(kickoff_at: Time.current..LEAD_MINUTES.max.minutes.from_now)

      upcoming.find_each do |match|
        minutes_left = ((match.kickoff_at - Time.current) / 60).floor
        floor = match.prematch_alert_min || (LEAD_MINUTES.max + 1)
        due = LEAD_MINUTES.select { |t| t < floor && t >= minutes_left }
        next if due.empty?

        Discord::Notifier.prematch(match, due.min)
        match.update!(prematch_alert_min: due.min)
      end
    end
  end
end
