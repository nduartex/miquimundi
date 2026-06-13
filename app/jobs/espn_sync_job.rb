class EspnSyncJob < ApplicationJob
  queue_as :default

  # Runs every minute via Solid Queue recurring. Cheap DB guard decides how
  # hard to work: full sync each minute while a match is live or about to
  # start, otherwise only a refresh every 15 minutes. ESPN being down is a
  # warning, never an error — the next cycle retries.
  def perform(force: false, dates: nil)
    tournament = Tournament.order(:year).last
    return unless tournament

    active = tournament.matches.where(kickoff_at: 3.hours.ago..10.minutes.from_now).exists?
    return unless force || active || Time.current.min % 15 == 0

    options = { standings: (force || !active) ? :force : :auto }
    options[:dates] = dates if dates
    Espn::SyncService.new(tournament).sync!(**options)
  rescue Espn::Client::Error => e
    Rails.logger.warn("[espn] sync skipped: #{e.message}")
  end
end
