class EspnSyncJob < ApplicationJob
  queue_as :default
  # One sync at a time: overlapping runs could race map_match / sync_goals.
  limits_concurrency to: 1, key: "espn_sync"

  IDLE_INTERVAL = 15.minutes
  LAST_SYNC_KEY = "espn_sync:last_run_at".freeze

  # Runs every minute via Solid Queue recurring. Cheap DB guard decides how
  # hard to work: full sync each minute while a match is live or about to
  # start, otherwise a refresh once the last successful run is older than
  # IDLE_INTERVAL (a timestamp, not a wall-clock minute check, so a busy
  # worker can't silently skip the beat). ESPN being down is a warning,
  # never an error — the next cycle retries.
  def perform(force: false, dates: nil)
    tournament = Tournament.current
    return unless tournament

    # The 4h window covers delayed kickoffs + extra time + penalties.
    active = tournament.matches.where(kickoff_at: 4.hours.ago..10.minutes.from_now).exists?
    last_run = Rails.cache.read(LAST_SYNC_KEY)
    idle_due = last_run.nil? || last_run < IDLE_INTERVAL.ago
    return unless force || active || idle_due

    options = { standings: (force || !active) ? :force : :auto }
    options[:dates] = dates if dates
    Espn::SyncService.new(tournament).sync!(**options)
    Rails.cache.write(LAST_SYNC_KEY, Time.current)
  rescue Espn::Client::Error => e
    Rails.logger.warn("[espn] sync skipped: #{e.message}")
  end
end
