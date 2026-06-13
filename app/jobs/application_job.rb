class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Report any unhandled job error to the Discord errors channel, then re-raise
  # so Solid Queue still records the failure and retries. Dormant until the
  # errors webhook URL is configured — report_error no-ops without it, and never
  # raises, so reporting can't mask or replace the original error.
  around_perform do |job, block|
    block.call
  rescue StandardError => e
    Discord::Notifier.report_error(e, context: { job: job.class.name, args: job.arguments })
    raise
  end
end
