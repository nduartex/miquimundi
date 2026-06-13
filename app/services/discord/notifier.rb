module Discord
  # Builds Discord webhook payloads and hands them to Discord::DeliverJob for
  # async delivery. The only side effect is enqueuing the job, so callers (the
  # ESPN sync, the prematch job, the global error hook) never touch HTTP and are
  # never slowed or broken by Discord being down. Delivery short-circuits when
  # the matching webhook URL isn't configured, so a whole channel can sit
  # dormant (the errors channel) until its URL is set.
  module Notifier
    module_function

    GREEN = 0x2ECC71
    BLUE = 0x3498DB
    RED = 0xE74C3C

    # Pings the whole server. Only the top-level `content` triggers mentions
    # (embed text never does), and allowed_mentions makes the @everyone fire
    # regardless of the webhook's default mention settings.
    EVERYONE = { content: "@everyone", allowed_mentions: { parse: [ "everyone" ] } }.freeze

    # All args are primitives (the sync passes plain strings/ints/bools).
    def goal(scorer:, scoring_team:, home_team:, away_team:, home_goals:, away_goals:, minute:, penalty:, own_goal:)
      score = "**#{home_team} #{home_goals} - #{away_goals} #{away_team}**"
      clock = minute.present? ? " (#{minute})" : ""

      if own_goal
        title = "⚽ Gol en contra"
        line = "#{scorer} (en contra)#{clock} — favorece a #{scoring_team}"
      else
        title = "⚽ ¡GOL de #{scoring_team}!"
        line = "#{scorer}#{penalty ? ' de penal' : ''}#{clock}"
      end

      deliver(:goals, **EVERYONE, embeds: [ { title: title, description: "#{line}\n\n#{score}", color: GREEN } ])
    end

    def prematch(match, minutes)
      fase = I18n.t("phase.#{match.phase}", default: "Fase de grupos")
      deliver(:goals, **EVERYONE, embeds: [ {
        title: "⏰ Faltan ~#{minutes} min",
        description: "**#{match.home_team&.name}** vs **#{match.away_team&.name}**\n#{fase}",
        color: BLUE
      } ])
    end

    # Reports an exception to the errors webhook. Wrapped so it can never raise:
    # it runs inside the global job error hook, where a failure here would mask
    # the original error.
    def report_error(exception, context: {})
      backtrace = Array(exception.backtrace).first(8).join("\n")
      details = context.map { |k, v| "**#{k}:** #{v}" }.join("\n")
      description = [ "```#{exception.message}```", details, "```#{backtrace}```" ].reject(&:blank?).join("\n")

      deliver(:errors, embeds: [ {
        title: "🚨 #{exception.class}",
        description: description.truncate(4000),
        color: RED
      } ])
    rescue StandardError => e
      Rails.logger.warn("[discord] report_error failed: #{e.class}: #{e.message}")
    end

    # nil when neither credentials nor ENV define the webhook → delivery no-ops.
    def webhook_url(key)
      credential = Rails.application.credentials.dig(:discord, :"#{key}_webhook_url")
      (credential.presence || ENV["DISCORD_#{key.to_s.upcase}_WEBHOOK_URL"]).presence
    end

    def deliver(key, payload)
      DeliverJob.perform_later(key.to_s, payload.deep_stringify_keys)
    end
  end
end
